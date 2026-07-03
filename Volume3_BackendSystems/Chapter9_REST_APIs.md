# Volume 3: Backend Systems
# Chapter 9: REST APIs and HTTP

---

## Table of Contents

1. REST Principles and Constraints
2. HTTP Methods
3. HTTP Status Codes
4. REST API Versioning
5. Idempotency
6. API Error Handling
7. Pagination
8. Request and Response Design
9. API Rate Limiting
10. Content Negotiation and Media Types
11. HTTP Caching
12. API Security Basics
13. REST vs GraphQL vs gRPC
14. OpenAPI and Swagger
15. API Gateway Patterns

---

> **How to read this chapter:** Each topic has three layers.
> - **The Idea** — start here, no prior knowledge needed.
> - **How It Works** — the real mechanism, patterns, and tradeoffs.
> - **Interview Lens** — what interviewers actually probe.
>
> Beginners: read all three layers top to bottom.
> SDE2/Senior: skim "The Idea", focus on "How It Works" and "Interview Lens".

---

## Topic 1: REST Principles and Constraints

---

#### The Idea

Think of a vending machine. You walk up, insert a coin, press a button, and get a snack. The machine does not know who you are, does not remember your last purchase, and does not care what you did before you arrived. Every interaction is self-contained. That is the core spirit of REST: each request carries everything the server needs to respond, and the server holds no memory of you between requests.

REST (Representational State Transfer) is not a protocol like HTTP — it is an architectural style, a set of six rules that Roy Fielding defined in his year-2000 dissertation. If your API follows all six rules, it is RESTful. Most production APIs follow most of the rules, but skip one or two for pragmatic reasons. Knowing the rules — and knowing which ones are commonly skipped — is what interviewers test.

The six constraints work together as a system. Removing any one of them changes what you can guarantee about the API's scalability, evolvability, and simplicity.

---

#### How It Works

```
The six REST constraints:

1. Client-Server
   - Separate UI concerns (client) from data/storage concerns (server)
   - Client does not know how the server stores data
   - Server does not know how the client renders it
   - Benefit: both sides can evolve independently

2. Stateless
   - Each request must contain ALL information needed to process it
   - Server holds NO session state between requests
   - Auth token, user context, pagination cursor — all go in each request
   - Benefit: any server in a cluster can handle any request (trivial horizontal scaling)

3. Cacheable
   - Responses must declare themselves cacheable or non-cacheable
   - Use Cache-Control, ETag, Last-Modified headers
   - Benefit: fewer round-trips, lower server load

4. Uniform Interface (the defining constraint of REST)
   Four sub-rules:
   a. Resources identified by URIs  →  /users/42, not /getUserById?id=42
   b. Manipulation via representations  →  client sends JSON, not SQL
   c. Self-descriptive messages  →  Content-Type header tells the server how to parse the body
   d. HATEOAS  →  responses embed links to related actions (see below)

5. Layered System
   - Client cannot tell if it is talking to the origin server, a CDN, a load balancer, or an API gateway
   - Benefit: security layers, caching layers, monitoring layers can be inserted transparently

6. Code-on-Demand (OPTIONAL)
   - Server can transfer executable code to the client (e.g., JavaScript)
   - Rarely used in REST APIs; the only optional constraint
```

**HATEOAS** (Hypermedia As The Engine Of Application State) is the must-memorise gotcha. It means responses include hyperlinks to available next actions, so a client can navigate the entire API from a single entry point without hardcoding URLs.

```java
// HATEOAS response example — what the JSON looks like
// GET /api/v1/orders/123
{
  "id": 123,
  "status": "PENDING",
  "amount": 49.99,
  "_links": {
    "self":    { "href": "/api/v1/orders/123" },
    "cancel":  { "href": "/api/v1/orders/123" },
    "confirm": { "href": "/api/v1/orders/123/confirm" }
  }
}
// When status becomes DELIVERED, the response drops "cancel"/"confirm"
// and adds "refund" — the client discovers valid actions from the response,
// not from hardcoded logic. This is HATEOAS in practice.
```

**Inline tradeoffs:** HATEOAS is theoretically powerful — clients never break when URLs change — but in practice most teams skip it. It adds response payload size, requires server-side link generation, and most client teams ignore the links anyway. Acknowledge the pragmatic trade-off in interviews.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What are the constraints of REST, and which one is most often violated in production?"**

**One-line answer:** REST has six constraints — stateless, client-server, cacheable, uniform interface, layered system, and code-on-demand — and HATEOAS (part of uniform interface) is the one most commonly skipped.

**Full answer to give in an interview:**

> "REST defines six architectural constraints. The core ones are: client-server separation, meaning the UI and data storage concerns are decoupled so each side can evolve independently; statelessness, meaning every request must carry all its own context — the server stores no session state between calls, which is what makes horizontal scaling trivial; cacheability, meaning responses declare themselves cacheable so intermediaries like CDNs can store them; and layered system, meaning the client cannot tell whether it is talking to the origin server or a load balancer or an API gateway. The most important constraint is the uniform interface — resources are identified by URIs, clients manipulate them through representations like JSON, and messages are self-descriptive using headers like Content-Type. The fourth sub-rule of uniform interface is HATEOAS, which stands for Hypermedia As The Engine Of Application State — it means responses embed links to related next actions so clients can navigate the API without hardcoded URLs. HATEOAS is the constraint almost no production team implements fully, because it adds complexity and most clients ignore the links. The sixth constraint, code-on-demand, is the only optional one and involves transferring executable code like JavaScript to the client."

> *Name all six, then zero in on HATEOAS as the practical skip — this shows depth.*

**Gotcha follow-up they'll ask:** *"So if we skip HATEOAS, is our API still RESTful?"*

> "Technically no — Fielding argued HATEOAS is mandatory for true REST. But in practice, the industry uses 'RESTful' loosely to mean 'HTTP API with proper verbs and status codes.' In interviews I acknowledge the distinction: our API is REST-like or HTTP-based, not strictly RESTful by Fielding's definition. The pragmatic trade-off is that HATEOAS adds coupling complexity and tooling burden that most teams cannot justify."

---

##### Q2 — Tradeoff Question
**"How does the stateless constraint affect authentication — can you use server-side sessions in a REST API?"**

**One-line answer:** Server-side sessions violate the stateless constraint — each request must carry its own auth context, which is why JWTs (tokens the client stores and sends on every request) are the idiomatic REST authentication mechanism.

**Full answer to give in an interview:**

> "The stateless constraint says the server must hold no session state between requests — every request must contain all the information needed to process it. Server-side sessions, where the server stores a session object in memory or Redis and the client only holds a session ID cookie, violate this constraint: the server now has per-client state that must be present for the request to be understood. This also hurts scalability — if session state lives on server A, subsequent requests must route to server A (sticky sessions), which defeats horizontal scaling. The idiomatic solution for REST is token-based authentication, typically JWTs — JSON Web Tokens. A JWT is a self-contained, cryptographically signed token that encodes the user's identity and permissions. The client stores it, sends it in the Authorization header on every request, and the server validates the signature without consulting any external store. No sticky sessions, any server in the cluster can handle any request."

> *If they nod, add: 'The trade-off is token revocation — you cannot invalidate a JWT before it expires without a deny-list, which reintroduces server-side state. This is the canonical JWT weakness.'*

**Gotcha follow-up they'll ask:** *"What is the Richardson Maturity Model?"*

> "It's a model by Leonard Richardson that grades REST APIs on four levels. Level 0 is a single endpoint where everything is POST — basically RPC over HTTP. Level 1 introduces multiple resources, each with its own URI. Level 2 adds proper HTTP verbs — GET to read, POST to create, DELETE to delete — and correct status codes. Level 3 adds HATEOAS. Most production APIs sit at Level 2. True Level 3 with HATEOAS is rare. The model is useful because it gives teams a shared vocabulary for 'how RESTful is our API.'"

---

> **Common Mistake — Calling any JSON API "RESTful":** Most APIs that call themselves REST are actually RPC-over-HTTP — they use POST for everything and have URLs like `/getUser` or `/createOrder`. This is Level 0 on the Richardson Maturity Model. The consequence in interviews: saying "we use REST" when describing an RPC-style API signals that you don't know the difference.

---

**Quick Revision (one line):**
REST's six constraints (stateless, client-server, cacheable, uniform interface with HATEOAS, layered system, code-on-demand) exist to make APIs scalable and evolvable; HATEOAS is the most powerful and most skipped.

---

## Topic 2: HTTP Methods

---

#### The Idea

Think of the verbs you use at a library desk. "Get me book 42." "Add this new book." "Replace the card in the catalogue for book 42 with this updated one." "Throw away book 42." Each verb carries a different expectation: some are read-only, some change state, and some guarantee that doing them twice is the same as doing them once.

HTTP methods work the same way. Every method carries a semantic contract — a promise about whether the operation reads or writes, and whether it is safe to repeat. These promises are not enforced by HTTP itself; they are obligations your server agrees to honour. When you honour them, clients, CDNs, and load balancers can make intelligent decisions: cache GET responses, retry idempotent operations on timeout, refuse to cache POST responses.

Two properties matter most: **safety** (the method causes no observable side effects — read-only) and **idempotency** (calling it N times produces the same server state as calling it once). Interviewers test both, and they will always ask about the edge cases.

---

#### How It Works

| Method  | Safe | Idempotent | Request Body | Common Use                        |
|---------|------|------------|--------------|-----------------------------------|
| GET     | Yes  | Yes        | No           | Retrieve a resource               |
| HEAD    | Yes  | Yes        | No           | Check existence / metadata only   |
| OPTIONS | Yes  | Yes        | No           | CORS preflight, capability check  |
| POST    | No   | No         | Yes          | Create a resource or trigger action |
| PUT     | No   | Yes        | Yes          | Full replacement of a resource    |
| PATCH   | No   | No*        | Yes          | Partial update of a resource      |
| DELETE  | No   | Yes        | Optional     | Delete a resource                 |

*PATCH can be made idempotent with a conditional `If-Match` header, but is not inherently idempotent.

```
Decision logic for choosing a method:

Is the operation read-only?
  YES → GET (with body in response) or HEAD (no body)
  NO  → continue

Does the client specify the resource ID?
  YES → PUT (full replace) or PATCH (partial update)
  NO  → POST (server assigns the ID)

Does the client send the complete resource?
  YES → PUT
  NO  → PATCH

Should repeated calls be safe to retry?
  PUT and DELETE are idempotent — retrying is safe
  POST is not — retrying may create duplicates → use idempotency keys (Topic 5)
```

The single must-memorise gotcha — **is DELETE idempotent if the second call returns 404?**

```java
// DELETE /products/42 — first call
// Server state: product 42 deleted
// HTTP response: 204 No Content

// DELETE /products/42 — second call (product is already gone)
// Server state: still no product 42 (unchanged)
// HTTP response: 404 Not Found

// Idempotency refers to SERVER STATE, not HTTP response code.
// The state after both calls is identical: product 42 does not exist.
// Therefore DELETE IS idempotent, even though the response code differs.
```

**POST vs PUT:** Use POST when the server assigns the resource ID (`POST /orders` → server creates order 999). Use PUT when the client specifies the ID (`PUT /orders/999` — full replacement). Calling `POST /orders` twice creates two orders; calling `PUT /orders/999` twice creates or replaces the same order.

**PUT vs PATCH:** PUT sends the complete resource — omitted fields are set to null or defaults. PATCH sends only the changed fields. For a resource with 20 fields, PATCH is more efficient and less error-prone than PUT.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Which HTTP methods are safe, which are idempotent, and what is the difference between the two?"**

**One-line answer:** Safe means read-only with no side effects (GET, HEAD, OPTIONS); idempotent means repeating the call leaves the server in the same state (GET, HEAD, PUT, DELETE); POST is neither.

**Full answer to give in an interview:**

> "Safety and idempotency are two separate HTTP contracts. A method is safe if it causes no observable side effects — it only reads, never writes. GET, HEAD, and OPTIONS are safe. Because they are read-only, clients can freely cache them, prefetch them, and retry them without worrying about unintended changes. Idempotency is a broader guarantee: calling the method multiple times with the same input produces the same server state as calling it once. GET and HEAD are both safe and idempotent. PUT and DELETE are idempotent but not safe — they do modify state, but doing it twice ends up in the same place as doing it once: PUT replaces a resource to the same result, DELETE leaves the resource absent. POST is neither safe nor idempotent — posting twice can create two resources. PATCH is not inherently idempotent either: `PATCH /counter {increment: 1}` applied twice gives a different result than applied once."

> *Pause after listing the table. The interviewer will almost certainly ask the DELETE follow-up.*

**Gotcha follow-up they'll ask:** *"Is DELETE idempotent if the second call returns 404?"*

> "Yes — idempotency is about server state, not the HTTP response code. After the first DELETE, the resource is gone. After the second DELETE, the resource is still gone. The server state is identical. The fact that the second call returns 404 instead of 204 is a response code difference, not a state difference. The HTTP spec explicitly says idempotency refers to the intended effect on the server, not the response."

---

##### Q2 — Tradeoff Question
**"When would you use PATCH instead of PUT, and is PATCH idempotent?"**

**One-line answer:** Use PATCH when updating a subset of fields to avoid accidentally nulling out fields you did not send; PATCH is not inherently idempotent, but can be made so with a conditional `If-Match` header.

**Full answer to give in an interview:**

> "PUT requires the client to send the complete resource representation. If I have a user with 20 fields and I only want to change the phone number, I still have to send all 20 fields with PUT — otherwise the server will set the unsent fields to null or default. That is error-prone and wasteful over the network. PATCH solves this: I send only the fields I want to change, and the server applies just those changes. For large or complex resources, PATCH is safer and more efficient. On idempotency: PATCH is not inherently idempotent because the operation might be relative rather than absolute. For example, `PATCH /counter` with `{increment: 1}` applied twice gives a different result than applied once — that is not idempotent. However, if I use an `If-Match` header with the current ETag — a hash representing the current state — the server will reject the second patch if the resource has changed, making it safe to retry."

> *If they probe further: mention JSON Merge Patch (RFC 7396) and JSON Patch (RFC 6902) as the two standard PATCH formats.*

**Gotcha follow-up they'll ask:** *"Why does Stripe use POST for almost everything instead of PUT?"*

> "Because idempotency keys make POST effectively idempotent. Stripe attaches an `Idempotency-Key` header to POST requests. If the server has already processed a request with that key, it returns the cached response instead of processing again. This gives POST the retry-safety of PUT, while keeping the semantics of 'create a new resource with a server-assigned ID.' It's a pragmatic deviation from pure REST — business semantics sometimes matter more than HTTP method purity."

---

> **Common Mistake — Using POST for reads:** Doing `POST /users/search` with a JSON body instead of `GET /users?name=alice` breaks caching — POST responses are never cached by default, so every search hits the server. The consequence is unnecessary load and slower responses. Use GET with query parameters for searches; only switch to POST if your filter object is genuinely too complex for a URL.

---

**Quick Revision (one line):**
GET/HEAD are safe and idempotent; PUT/DELETE are idempotent but not safe; POST is neither; PATCH is not inherently idempotent but can be made so with `If-Match`.

---

## Topic 3: HTTP Status Codes

---

#### The Idea

Imagine ordering at a restaurant. The waiter can come back with five types of news: "Here is your food" (success), "We moved the pasta to a new menu section, follow me" (redirect), "I'm sorry, your order form was filled out wrong" (your fault), or "The kitchen is on fire" (our fault). HTTP status codes work the same way — grouped by who caused the problem and what the client should do next.

Every status code belongs to a family defined by its first digit. The family tells the client the broad category of outcome; the specific code within the family tells it exactly what happened. A client that understands the family can do something sensible even if it does not recognise the specific three-digit code.

The codes you choose are a contract with your clients. Using 200 OK for an error, or 500 for a validation failure the client caused, breaks that contract — monitoring systems misfire, retry logic misbehaves, and client developers waste hours debugging.

---

#### How It Works

```
Status code families:

1xx — Informational   (request received, continuing)
2xx — Success         (request received, understood, accepted)
3xx — Redirection     (further action needed to complete the request)
4xx — Client Error    (request has bad syntax or cannot be fulfilled — client's fault)
5xx — Server Error    (server failed to fulfil a valid request — server's fault)
```

**2xx — Success codes to know:**

| Code | Name               | When to use                                                        |
|------|--------------------|--------------------------------------------------------------------|
| 200  | OK                 | GET, PUT, PATCH success — include response body                   |
| 201  | Created            | POST created a resource — must include `Location` header          |
| 202  | Accepted           | Request accepted, processing is async — include polling URL       |
| 204  | No Content         | Success with no body — DELETE, or PUT/PATCH that returns nothing  |

**3xx — Redirect codes to know:**

| Code | Name               | When to use                                                        |
|------|--------------------|--------------------------------------------------------------------|
| 301  | Moved Permanently  | Resource has a new permanent URI — safe to cache                  |
| 302  | Found              | Temporary redirect — do not cache, do not update bookmarks        |
| 304  | Not Modified       | Response to conditional GET — client's cached copy is still valid |
| 307  | Temp Redirect      | Temporary, but preserves HTTP method (won't turn POST into GET)   |

**4xx — Client error codes to know:**

| Code | Name                  | When to use                                                       |
|------|-----------------------|-------------------------------------------------------------------|
| 400  | Bad Request           | Malformed JSON, missing required field, unparseable input        |
| 401  | Unauthorized          | Not authenticated — confusingly named, means "send credentials"  |
| 403  | Forbidden             | Authenticated but not authorised — access denied                 |
| 404  | Not Found             | Resource does not exist (also used to hide existence from 403)   |
| 409  | Conflict              | Duplicate key, optimistic lock failure, version mismatch         |
| 422  | Unprocessable Entity  | Syntactically valid but semantically wrong (business rule fail)  |
| 429  | Too Many Requests     | Rate limit hit — include `Retry-After` header                    |

**5xx — Server error codes to know:**

| Code | Name                  | When to use                                                       |
|------|-----------------------|-------------------------------------------------------------------|
| 500  | Internal Server Error | Generic — avoid for known error conditions                       |
| 502  | Bad Gateway           | Upstream service returned invalid response                       |
| 503  | Service Unavailable   | Overloaded or in maintenance — include `Retry-After`             |
| 504  | Gateway Timeout       | Upstream service timed out                                       |

The must-memorise gotcha — **400 vs 422 and 401 vs 403:**

```java
// 400 vs 422 — which to use for validation errors?
// 400 Bad Request  → the request body CANNOT BE PARSED
//    e.g., malformed JSON, wrong Content-Type, missing required field at parse time
// 422 Unprocessable Entity → request is SYNTACTICALLY valid but SEMANTICALLY wrong
//    e.g., "end date must be after start date", "insufficient account balance"
// Rule of thumb: if the error is a JSON parsing failure → 400
//                if the error is a business rule violation → 422

// 401 vs 403 — the naming trap in the HTTP spec
// 401 Unauthorized → actually means UNAUTHENTICATED
//    The client has not provided credentials, or credentials are invalid
//    Response must include: WWW-Authenticate: Bearer realm="api"
//    Client should: provide credentials and retry
// 403 Forbidden → means AUTHENTICATED but NOT AUTHORISED
//    The server knows who you are, but you are not allowed to do this
//    Client should: NOT retry with the same credentials (it will not help)
// Security note: return 404 instead of 403 when you want to hide that a resource exists
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the difference between 401 and 403?"**

**One-line answer:** 401 means the client has not authenticated (no valid credentials were provided); 403 means the client is authenticated but does not have permission — retrying with the same credentials will not help.

**Full answer to give in an interview:**

> "The naming in the HTTP spec is famously confusing. 401 is called 'Unauthorized' but it actually means 'Unauthenticated' — the client either did not send credentials or sent invalid ones. The server is saying: I don't know who you are, please identify yourself. The response must include a `WWW-Authenticate` header telling the client how to authenticate. 403 is called 'Forbidden' and it means exactly that — the server knows who you are (you are authenticated) but you are not allowed to perform this action. The key practical difference: a 401 tells the client to get valid credentials and retry; a 403 tells the client that retrying with the same credentials is pointless. There is a third case worth mentioning: if you want to hide whether a resource even exists — for security-sensitive APIs where you do not want attackers to know an ID is valid — you return 404 instead of 403. GitHub does this for private repositories: they return 404 to unauthenticated users rather than 403, so you cannot tell whether the repo exists."

> *This is a high-signal answer — mentioning the security angle of 404-vs-403 shows production experience.*

**Gotcha follow-up they'll ask:** *"Should you return 404 or 200 with an empty array for a collection with no items?"*

> "200 with an empty array. A 404 would mean the collection itself does not exist — the endpoint is invalid. An empty collection is a valid, successful response: the resource exists, there are just zero items in it. Returning 404 for an empty list is a common mistake that breaks clients expecting to iterate over an array."

---

##### Q2 — Tradeoff Question
**"When would you use 202 Accepted instead of 201 Created?"**

**One-line answer:** Use 201 when the resource is created synchronously and you can return it immediately; use 202 when the creation is asynchronous and the client needs a way to poll for the result.

**Full answer to give in an interview:**

> "201 Created is the right response when a POST request creates a resource synchronously — the resource exists by the time the response is sent, and the `Location` header points to it. 202 Accepted means the request has been received and queued, but processing has not completed yet. This is appropriate for long-running operations: generating a report, processing a large file upload, triggering a background job. The 202 response should include a way for the client to check the status — typically a `Location` header pointing to a job status endpoint, or a body with a job ID and a polling URL. The client then polls that URL until the status transitions from PENDING to COMPLETED or FAILED. A real example: a video transcoding API. You POST a video file and get back 202 with `/jobs/abc123`. You poll `/jobs/abc123` until it returns a completed status with a link to the processed video."

> *Mention the polling pattern — it shows you think about the full async flow, not just the status code.*

**Gotcha follow-up they'll ask:** *"What is wrong with returning 200 with a JSON error body like `{\"success\": false, \"error\": \"not found\"}`?"*

> "It breaks HTTP semantics in several ways. Monitoring systems use status codes to detect errors — if everything returns 200, alerts never fire and dashboards show 100% success while the application is broken. Retry logic in HTTP clients and proxies is keyed on status codes — a 503 triggers automatic retry with backoff; a 200 does not. Caching also misbehaves: a 200 response may be cached by a CDN, so clients will repeatedly receive the cached error. And client developers have to parse every response body to check for errors instead of checking the status code, which is expensive and error-prone."

---

> **Common Mistake — Using 500 for client-caused errors:** If a client sends a bad request body and the server throws an uncaught exception that bubbles up as 500, the client gets a server-error signal for what is really a client error. Monitoring fires server-error alerts for a client bug. Always catch known error conditions (validation failures, not-found, conflicts) and return the correct 4xx code. Reserve 500 for genuinely unexpected server failures.

---

**Quick Revision (one line):**
2xx = success (201 for create + Location, 204 for no body); 4xx = client fault (400 = bad syntax, 401 = unauthenticated, 403 = unauthorised, 409 = conflict, 422 = business rule); 5xx = server fault; never return 200 with an error body.

---

## Topic 4: REST API Versioning

---

#### The Idea

Imagine you are a bank that printed 10 million cheque books with your address on them. You move offices. You cannot recall all the cheque books — clients are already using them. You have to keep accepting mail at the old address and forward it to the new one, while also accepting mail at the new address. That is the backwards-compatibility problem every API team faces the moment a real client depends on their API.

Versioning is how you tell clients: "This is the contract I am committing to. If I need to break it, I will create a new version so your existing code keeps working." Without versioning, every breaking change — renaming a field, changing a type, removing an endpoint — forces every client to update simultaneously, which is usually impossible in a distributed ecosystem.

There are four main strategies. Each trades off developer experience, HTTP purity, and operational complexity differently. Interviewers want you to know all four and be able to explain when you would choose each one.

---

#### How It Works

```
Four versioning strategies:

1. URI Path Versioning
   /api/v1/users/42
   /api/v2/users/42

   Pros: visible in browser, easy to test, CDN can route by prefix, easy to document
   Cons: violates REST (URI should identify a resource, not an API version),
         clutters URL structure, bookmarks break on deprecation
   Used by: Stripe (/v1/), GitHub (/v3/)

2. Query Parameter Versioning
   /api/users/42?api-version=1
   /api/users/42?api-version=2

   Pros: backward-compatible (default version can be assumed), easy to add later
   Cons: caching is harder (CDNs must vary by query param), easy to forget
   Used by: Microsoft Azure REST API (?api-version=2023-01-01)

3. Custom Request Header
   GET /api/users/42
   API-Version: 2

   Pros: keeps URIs clean, semantically correct (URI identifies resource)
   Cons: invisible in browser, can't test from URL bar,
         some proxies strip custom headers
   Used by: internal enterprise APIs

4. Content Negotiation (Accept header)
   GET /api/users/42
   Accept: application/vnd.mycompany.api.v2+json

   Pros: most RESTful — follows HTTP spec perfectly,
         clients can request multiple versions
   Cons: complex to implement, hard to test without tools,
         unfamiliar to most developers
   Used by: GitHub (application/vnd.github.v3+json), Atlassian

Decision guide:
  External public API with many client types → URI versioning (best DX)
  Internal API where clients are controlled → header versioning (clean URIs)
  Strict REST compliance required → content negotiation
  Adding versioning to an existing Azure-ecosystem API → query parameter
```

The must-memorise gotcha — **how Stripe communicates deprecation:**

```java
// Stripe-style date-based versioning via response headers
// The Deprecation + Sunset + Link header pattern

@GetMapping(value = "/{id}", headers = "API-Version=1")
public ResponseEntity<UserResponseV1> getUserV1(@PathVariable Long id) {
    UserResponseV1 user = userService.findByIdV1(id);
    return ResponseEntity.ok()
        .header("Deprecation", "true")
        .header("Sunset", "Sat, 31 Dec 2025 23:59:59 GMT")  // when v1 dies
        .header("Link", "</api/v2/users/" + id + ">; rel=\"successor-version\"")
        .body(user);
}
// Clients that monitor these headers know to migrate before the Sunset date.
// This is the industry-standard deprecation pattern — know it cold.
```

**Inline tradeoffs:** URI versioning has the best developer experience but offends REST purists. Content negotiation is the most RESTful but almost no one uses it day-to-day. In interviews, state the trade-offs, then give a recommendation — "for a public API I would use URI versioning for developer experience; for an internal API with controlled clients I would use header versioning to keep URIs clean."

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What are the four REST API versioning strategies, and which would you choose for a public API?"**

**One-line answer:** URI path, query parameter, custom header, and content negotiation — for a public API I would choose URI path versioning for developer experience, despite it technically violating REST purity.

**Full answer to give in an interview:**

> "There are four main strategies. URI path versioning puts the version in the URL itself — `/api/v1/users` — which makes it immediately visible, easy to test in a browser, easy to route at the CDN or load balancer level, and easy to document. The downside is that it technically violates REST, which says URIs should identify resources not API versions. Query parameter versioning appends a version parameter — `/api/users?api-version=1` — which is backward-compatible since you can default to the latest version, but it makes caching harder because CDNs need to vary by query parameter. Custom header versioning keeps the URI clean and is semantically correct — the URI identifies the resource, the header describes how to process the response — but it is invisible in a browser and some proxies strip custom headers. Content negotiation uses the Accept header with a vendor MIME type like `Accept: application/vnd.mycompany.v2+json` — the most RESTful approach, used by GitHub's API — but it is complex to implement and unfamiliar to most developers. For a public API I would use URI versioning: developer experience matters most when external teams are integrating, and the ability to test any version simply by typing a URL is a significant practical advantage."

> *Always conclude with a recommendation — interviewers want to see you can make a decision, not just list options.*

**Gotcha follow-up they'll ask:** *"How do you deprecate an old version without breaking existing clients?"*

> "The industry standard is to use three HTTP response headers on the old version's responses. The `Deprecation: true` header signals that this endpoint is deprecated. The `Sunset` header gives a specific date and time when the version will be shut down — for example, `Sunset: Sat, 31 Dec 2025 23:59:59 GMT`. The `Link` header points to the successor version — `Link: </api/v2/users/42>; rel=successor-version`. Clients that monitor these headers get advance warning. You also announce the timeline in changelogs and email registered developers. On the operational side, you track which client IDs are still calling the deprecated version and reach out directly to those teams before the sunset date."

---

##### Q2 — Tradeoff Question
**"What counts as a breaking change in an API, and how do you make changes without breaking clients?"**

**One-line answer:** A breaking change is anything that causes existing correct client code to fail — removing or renaming a field, changing a type, or removing an endpoint; additive changes (new optional fields, new endpoints) are non-breaking.

**Full answer to give in an interview:**

> "Breaking changes are anything a correct existing client depends on that you remove or alter. The classic examples: removing a field from a response — a client that reads `user.phoneNumber` will now get null or an error. Renaming a field — `firstName` becomes `first_name`, the client's JSON mapping breaks silently. Changing a field's type — `id` changes from integer to string, which breaks clients that store it as a number. Removing or renaming an endpoint. Changing an enum to add a new value that clients do not handle. Changing error codes or error response structure. Non-breaking changes are additive: adding a new optional field to a response, adding a new endpoint, adding a new optional request parameter. The strategy is: never make breaking changes on an existing version. Instead, release a new version, run both versions in parallel, set a deprecation timeline, and give clients months to migrate. For each individual response model, use a tolerant reader pattern — parse only the fields you know about and ignore unknown fields so new fields added by the server do not break old clients."

> *Mention the tolerant reader pattern — it signals distributed systems awareness.*

**Gotcha follow-up they'll ask:** *"What about versioning webhook payloads?"*

> "This is a commonly forgotten area. Webhooks are outbound HTTP calls from the server to the client, so the client's code depends on the payload structure just as much as on REST responses. Webhook payloads must be versioned too — either by including a version field in the payload itself, or by sending a `Webhook-Version` header. Stripe includes a `api_version` field in every webhook event. If you change the payload structure without versioning, every client webhook handler breaks simultaneously."

---

> **Common Mistake — Not versioning from day one:** Teams often say "we won't need it" and ship a v0 or versionless API. The moment a real client depends on it, every breaking change requires coordinating all clients simultaneously — which is frequently impossible. The cost of adding versioning later is far higher than adding it on day one. Always start with `/v1/`.

---

**Quick Revision (one line):**
URI versioning (`/v1/`) is most practical for public APIs; content negotiation is most RESTful; always version from day one and communicate deprecation via `Deprecation` + `Sunset` + `Link` headers.

---

## Topic 5: Idempotency

---

#### The Idea

Imagine you press the elevator button once, then press it again because the elevator is taking a while. The second press does nothing — the elevator is already coming. That is idempotency in everyday life: doing the same thing twice has the same outcome as doing it once.

Now imagine a different scenario: you tap your card at a payment terminal to pay £50. The terminal processes the charge but the network drops before the confirmation reaches your app. Your app does not know if the charge went through. Should it retry? Without a mechanism to deduplicate, a retry would charge you £100. This is the exact problem idempotency keys solve in distributed systems.

Networks are unreliable by nature. Requests time out. Responses get lost in transit. The client does not know if the server processed the request. In a system handling payments, bookings, or any operation with real-world consequences, you must be able to safely retry failed requests without duplicating the effect. Idempotency keys — a UUID the client generates and sends with the request, which the server uses to deduplicate — are the industry-standard solution, pioneered by Stripe.

---

#### How It Works

```
Idempotency key pattern (Stripe model):

Client side:
  1. Generate a UUID v4 per logical operation (not per retry)
     key = UUID.randomUUID()  // e.g., "a8098c1a-f86e-11da-bd1a-00112444be1e"
  2. Send: Idempotency-Key: <uuid> in the request header
  3. On timeout/network error: retry with the SAME key
  4. On success: discard the key (do not reuse for a different operation)

Server side:
  1. Extract Idempotency-Key header
  2. Look up key in idempotency store (Redis with TTL, or DB table)
  3. If key found AND request is complete:
       → return the CACHED response (do not re-process)
  4. If key found AND request is in progress (concurrent duplicate):
       → return 409 Conflict or wait for completion
  5. If key is new:
       → process the request
       → store (key → {status_code, response_body, request_hash, timestamp})
       → return response
  6. Keys expire after 24–48 hours

Body hash check (critical):
  When a key is found, verify the request body matches the original.
  Same key + different body → 422 Unprocessable Entity (key reused incorrectly)
  This prevents a client bug from being silently ignored.
```

The must-memorise gotcha — **the difference between idempotent and safe, and why PUT is idempotent but not safe:**

```java
// SAFE vs IDEMPOTENT — they are NOT the same property

// SAFE: the method has NO OBSERVABLE SIDE EFFECTS (read-only)
//   GET  → safe (reading does not change server state)
//   HEAD → safe

// IDEMPOTENT: calling N times = calling it once (same server state result)
//   GET    → idempotent (and safe)
//   PUT    → idempotent but NOT safe
//   DELETE → idempotent but NOT safe

// PUT example — why it is idempotent but not safe:
// PUT /products/42 { "price": 99.99 }  ← first call: sets price to 99.99 (WRITES state)
// PUT /products/42 { "price": 99.99 }  ← second call: price is still 99.99 (same result)
// The operation is NOT safe because it modifies state.
// The operation IS idempotent because repeating it leaves the same state.

// POST example — why it is neither:
// POST /orders { "item": "book" }  ← first call: creates order #1
// POST /orders { "item": "book" }  ← second call: creates order #2  ← DIFFERENT RESULT
// Not safe (writes), not idempotent (different state each time)

// The practical implication:
// PUT can be retried safely on timeout — worst case is a redundant write
// POST CANNOT be retried safely without idempotency keys — risk of duplicate side effects
```

**Storage for idempotency keys:**

```
Redis (preferred for high-throughput):
  key: "idempotency:{uuid}"
  value: {statusCode, responseBody, requestBodyHash, processedAt}
  TTL: 24 hours
  Pros: fast, TTL is automatic
  Cons: volatile — if Redis fails, idempotency store is lost

Database (fallback / financial systems):
  Table: idempotency_keys (idempotency_key, endpoint, response_body, status_code, expires_at)
  Unique constraint on (idempotency_key, endpoint)
  Pros: durable, survives Redis failures
  Cons: slower, needs periodic cleanup of expired rows

Best practice: Redis as primary, DB as fallback for critical financial operations.
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is idempotency, and why does it matter in distributed systems?"**

**One-line answer:** Idempotency means performing the same operation multiple times produces the same result as performing it once — it matters because network failures force retries, and without idempotency, retries cause duplicate side effects like double charges.

**Full answer to give in an interview:**

> "Idempotency means that applying the same operation N times leaves the server in exactly the same state as applying it once. In a distributed system, this matters because networks are unreliable. A client sends a POST request to create a payment. The server processes the charge, the customer's card is debited, but the network drops before the response reaches the client. The client has no way to know if the charge succeeded. If it retries without idempotency, the customer gets charged twice — which is catastrophic for a payments company. Idempotency keys solve this: the client generates a UUID once per logical operation — not per retry — and sends it in an `Idempotency-Key` header. The server stores this key with the result in Redis or a database. On a retry with the same key, the server detects it is a duplicate and returns the cached response instead of re-processing. The operation executes exactly once regardless of how many times the client retries. Stripe pioneered this pattern and it has become the industry standard for any API that triggers side effects — payments, email sends, order creation."

> *Emphasise 'one UUID per logical operation, not per retry' — this is a common misunderstanding.*

**Gotcha follow-up they'll ask:** *"How do you handle a race condition where two concurrent retries arrive before either is processed?"*

> "This is the distributed idempotency race condition. Two threads arrive simultaneously with the same idempotency key, both check the store, both find nothing, and both start processing — resulting in a duplicate. The solution is to use an atomic check-and-set at the storage layer. With Redis, you use `SETNX` — Set if Not Exists — which is atomic: only one of the two threads wins the `SETNX`, the other finds the key already set and knows to wait or return the cached result. With a relational database, you use a unique constraint on the idempotency key column: one insert succeeds, the other throws a unique constraint violation, which you catch and treat as a duplicate. The key insight is that the deduplication check and the 'I am now processing this key' claim must be a single atomic operation."

---

##### Q2 — Tradeoff Question
**"PUT is idempotent — so why would you ever add idempotency keys to a PUT endpoint?"**

**One-line answer:** HTTP-level idempotency guarantees the state ends up the same, but it does not guarantee the operation ran exactly once — for financial operations, explicit idempotency keys add a layer of business-level deduplication and auditability beyond what HTTP promises.

**Full answer to give in an interview:**

> "PUT is idempotent at the HTTP level: sending the same PUT twice results in the same server state. But there is a distinction between HTTP-level idempotency and business-level idempotency. HTTP-level says: the resource ends up in the same state. Business-level says: the side effects were triggered exactly once. Consider a PUT that updates a bank transfer. The final state of the transfer record might be identical whether PUT ran once or twice, but if the actual fund movement is triggered by the first save event, triggering it twice could have external consequences even though the database row looks the same. For payment and financial APIs, teams add explicit idempotency keys to PUT and PATCH endpoints too — not because the resource state would differ, but because it adds an audit trail showing exactly which client request triggered each state change, enables deduplication of events flowing into downstream systems, and provides a clean retry story for clients operating in unreliable network conditions. The trade-off is storage cost and implementation complexity."

> *The phrase 'HTTP-level vs business-level idempotency' is high signal — it shows systems thinking.*

**Gotcha follow-up they'll ask:** *"Should you store idempotency keys in Redis or the database?"*

> "It depends on the durability requirement. Redis is fast and handles high throughput well, and TTL-based expiry is automatic — you set a 24-hour TTL and Redis evicts the key automatically. The risk is that Redis is in-memory and volatile: if Redis goes down without persistence configured, your idempotency store is lost, and any in-flight retries during that window could duplicate. For financial operations, many teams use both: Redis as the fast primary lookup, and a relational database table with a unique constraint on the idempotency key as a durable fallback. The database also gives you an audit trail — you can query which idempotency keys were used, when, and what they returned, which is valuable for reconciliation."

---

> **Common Mistake — Reusing an idempotency key for a different operation:** The key is meant to identify one specific logical operation. A client that reuses the same UUID for a retry of a different operation will receive the cached response from the first operation silently, with no error. The server should detect this by hashing the request body and comparing it to the stored hash — if the key matches but the body differs, return 422 Unprocessable Entity. This check is essential and easy to forget.

---

**Quick Revision (one line):**
Idempotency keys let clients safely retry POST requests — client generates one UUID per logical operation, server caches the result keyed on it in Redis with a 24-hour TTL, and returns the cached response on any retry with the same key.

---

## Topic 6: API Error Handling

---

#### The Idea

Imagine you order food at a restaurant, but your dish isn't available. A bad waiter just walks away and says nothing. A good waiter says: "Sorry, the salmon is out. Here's why, and here's what I can offer instead." API error handling works the same way — when something goes wrong, your API must clearly explain what went wrong, why, and what the client can do about it.

Without consistent error handling, every endpoint becomes its own mystery. A client might get a 200 OK with an embedded "error: true" field from one endpoint, a plain string from another, and a stack trace from a third. Clients can't reliably handle these differences — they end up writing fragile one-off logic for each endpoint.

The industry-standard solution is RFC 7807 "Problem Details for HTTP APIs." It defines a standard JSON structure for errors, carried under the `application/problem+json` content type. Every error your API returns looks the same — machine-readable, human-readable, and linkable to documentation.

---

#### How It Works

HTTP status codes are the first signal — they tell the client the broad category of the problem:

```
2xx — success (200 OK, 201 Created, 204 No Content)
4xx — client error (the request was wrong)
  400 Bad Request       — malformed syntax, invalid field
  401 Unauthorized      — not authenticated
  403 Forbidden         — authenticated but not allowed
  404 Not Found         — resource doesn't exist
  409 Conflict          — state conflict (e.g. duplicate)
  422 Unprocessable Entity — valid syntax, but fails business rules
  429 Too Many Requests — rate limit exceeded
5xx — server error (the server failed)
  500 Internal Server Error — unexpected crash
  503 Service Unavailable   — downstream dependency down
```

RFC 7807 standardises the response body. The must-memorise format — use this exactly in interviews and in code:

```json
{
  "type": "https://api.example.com/errors/insufficient-funds",
  "title": "Insufficient Funds",
  "status": 422,
  "detail": "Your account balance of $10.00 is below the required $25.00.",
  "instance": "/accounts/abc123/transactions/txn-456"
}
```

The fields mean:
- `type` — a URI that identifies the error class (links to docs)
- `title` — short human-readable label for this error class (stable)
- `status` — the HTTP status code (repeated for convenience)
- `detail` — human-readable explanation specific to this occurrence
- `instance` — URI of the specific request/resource that triggered it

You can add custom extension fields (e.g., `"balance": 10.00`, `"required": 25.00`) to carry machine-readable data without breaking the standard shape.

Tradeoff: a more detailed error body helps developers debug faster but can leak internal implementation details (table names, stack traces, internal IDs) — never expose those. Filter what you return through a dedicated error-mapping layer.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is RFC 7807 and why should APIs use it?"**

**One-line answer:** RFC 7807 defines a standard JSON error body structure so all API errors look the same and clients can handle them generically.

**Full answer to give in an interview:**

> "RFC 7807, called 'Problem Details for HTTP APIs,' is an IETF standard that defines a consistent JSON shape for error responses. You use the `application/problem+json` content type to signal it. The body always includes a `type` field — a URI identifying the error class — a `title`, a `status` code, a human-readable `detail`, and an `instance` URI pointing to the specific request. The reason this matters is that without it, every team invents their own error format. Clients end up writing different parsing logic for each endpoint. With RFC 7807, a single error-handling function covers all endpoints. You can also add extension fields for machine-readable data — things like the current balance and required amount for a payment failure — without breaking the standard structure."

> *Sketch the JSON shape if you have a whiteboard. Mention `application/problem+json` as the content type — interviewers notice that detail.*

**Gotcha follow-up they'll ask:** *"What's the difference between 401 and 403?"*

> "401 Unauthorized means the request has no valid authentication — the client isn't identified at all, or their token is expired. Despite the name, it's really about authentication, not authorisation. 403 Forbidden means the client is authenticated — we know who they are — but they don't have permission to perform this action. A practical example: a user who is logged in but tries to access another user's private data gets a 403, not a 401."

---

##### Q2 — Tradeoff Question
**"When should you use 400 Bad Request versus 422 Unprocessable Entity?"**

**One-line answer:** 400 is for syntactically malformed requests; 422 is for requests that are syntactically valid but fail business or semantic validation.

**Full answer to give in an interview:**

> "400 Bad Request means the server couldn't even parse the request — the JSON is malformed, a required field is missing entirely, or the data type is wrong (sending a string where an integer is expected). 422 Unprocessable Entity means the server parsed the request fine, but the content fails business logic validation — for example, a transfer amount that exceeds the account balance, or a date range where the end date is before the start date. The practical rule: if it would fail before your business logic even runs, return 400; if it passes structural validation but fails a business rule, return 422. Some teams use 400 for both, which is acceptable, but 422 gives clients cleaner signal about what kind of error handling is needed."

> *This distinction trips up a lot of candidates. Saying '422 is for semantic validation failures' shows depth.*

**Gotcha follow-up they'll ask:** *"How do you avoid leaking sensitive information in error messages?"*

> "You map all internal exceptions through a global error handler — in Spring Boot that's a `@ControllerAdvice` class, in Express it's a central error-handling middleware. That handler converts internal exceptions to RFC 7807 bodies, stripping out stack traces, internal class names, database error codes, and any field that could help an attacker fingerprint your infrastructure. You log the full internal error server-side (with a correlation ID) but only return the sanitised public version to the client. The `instance` field in RFC 7807 is a good place to put that correlation ID so the client can share it for debugging without the server exposing internals."

---

##### Q3 — Design Scenario
**"Design the error handling strategy for a payment processing API."**

**One-line answer:** Use RFC 7807 with domain-specific error type URIs, a global exception handler, and separate machine-readable codes from human-readable messages.

**Full answer to give in an interview:**

> "I'd start with RFC 7807 as the base. For payment APIs, the `type` URIs map to specific error classes in our docs — `https://api.payments.com/errors/insufficient-funds`, `https://api.payments.com/errors/card-declined`, `https://api.payments.com/errors/duplicate-transaction`. These are stable identifiers that client code can branch on without parsing human-readable strings, which might change. I'd add extension fields: `decline_code` for card network decline reasons (the machine-readable sub-code), and `balance` and `required` for insufficient-funds cases. I'd use a global exception handler that catches domain exceptions and maps them to the right HTTP status plus RFC 7807 body. No stack traces ever leave the server. Each error response includes a `correlation_id` so support teams can look up the full internal log. Finally, all 5xx errors return a generic message — 'An unexpected error occurred' — to prevent infrastructure leakage."

> *Mentioning a stable `type` URI (not a message string) for client branching is the detail that separates senior answers from junior ones.*

---

> **Common Mistake — Inconsistent error formats:** Using different error shapes per endpoint forces clients to write fragile one-off parsers. A single global error handler that always returns RFC 7807 costs almost nothing to implement but makes the API vastly easier to consume.

---

**Quick Revision (one line):**
RFC 7807 defines a standard `application/problem+json` error body with `type`, `title`, `status`, `detail`, and `instance` fields — use a global exception handler to enforce it everywhere and never expose stack traces.

---

## Topic 7: Pagination

---

#### The Idea

Imagine searching a library with a million books and someone dumps all of them on your desk at once. That's what happens when an API returns an entire database table in one response. Pagination is the practice of splitting large result sets into manageable pages — the API returns a subset of results and enough information for the client to fetch the next chunk.

This isn't just a performance optimisation. Without pagination, a single slow query can time out, a single large response can exhaust client memory, and the server has no way to protect itself from clients accidentally (or deliberately) fetching millions of rows. Pagination is a contract: "here's what you asked for, and here's how to get more."

There are three main approaches — offset, cursor, and keyset — and they have very different performance and correctness characteristics. Most production APIs start with offset pagination (because it's simple) and migrate to cursor or keyset pagination when they hit scale problems.

---

#### How It Works

**Offset pagination** uses `page` and `size` (or `offset` and `limit`) parameters:

```
GET /orders?page=3&size=20
→ SELECT * FROM orders ORDER BY created_at DESC LIMIT 20 OFFSET 60
```

Simple to implement and supports jumping to any page. The problem: at large offsets the database must scan and discard thousands of rows before returning the 20 you actually want. At `OFFSET 100000`, even with an index, this is a full scan of 100,000 rows.

**Cursor pagination** returns an opaque cursor token the client passes in the next request:

```
GET /orders
→ { data: [...], next_cursor: "eyJpZCI6MTIzNH0=" }

GET /orders?cursor=eyJpZCI6MTIzNH0=
→ decode cursor → WHERE id < 1234 ORDER BY id DESC LIMIT 20
```

The cursor encodes the position in the result set. The server decodes it and issues a `WHERE` clause instead of `OFFSET`. This is always a fast index seek regardless of how deep into the result set you are.

**Keyset pagination** is cursor pagination made explicit — instead of opaque tokens, the client passes the last-seen sort key directly:

```
GET /orders?after_id=1234&after_created_at=2024-01-15T10:00:00Z
→ WHERE (created_at, id) < ('2024-01-15T10:00:00Z', 1234)
   ORDER BY created_at DESC, id DESC LIMIT 20
```

| | Offset | Cursor | Keyset |
|---|---|---|---|
| **Implementation** | Simple | Medium | Medium |
| **Jump to page N** | Yes | No | No |
| **Performance at depth** | Degrades (O(offset)) | Constant | Constant |
| **Stable under inserts/deletes** | No (items shift) | Yes | Yes |
| **Requires unique sort key** | No | Yes | Yes |
| **Exposes sort key to client** | N/A | No (opaque token) | Yes |
| **Best for** | Small datasets, admin UIs | Infinite scroll, feeds | High-volume APIs |

Response envelope for cursor pagination:

```
GET /orders?cursor=<token>&size=20

Response:
{
  "data": [ ...20 orders... ],
  "pagination": {
    "next_cursor": "eyJjcmVhdGVkX2F0IjoiMjAyNC0wMS0xNVQxMDowMDowMFoiLCJpZCI6MTIzNH0=",
    "has_more": true,
    "size": 20
  }
}
```

When `has_more` is false, the client stops paginating. Never expose `total_count` with cursor pagination — counting all rows is expensive and defeats the point.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Why is offset pagination a problem at scale, and what replaces it?"**

**One-line answer:** Offset pagination forces the database to scan and discard N rows before returning your page, which gets slower as N grows — cursor or keyset pagination replaces the offset with a `WHERE` clause that uses an index directly.

**Full answer to give in an interview:**

> "With offset pagination, you issue `LIMIT 20 OFFSET 100000`. Even with an index on the sort column, the database engine has to traverse 100,000 index entries before it can start returning results. The index helps with ordering but not with skipping — you're paying a linear cost that grows with every deeper page. At page 5,000 this becomes genuinely slow. Cursor or keyset pagination solves this by converting the 'skip N rows' problem into a 'fetch rows after this point' problem. You encode the last item you saw — its ID, its timestamp — and the next query becomes `WHERE (created_at, id) < (last_created_at, last_id) ORDER BY created_at DESC LIMIT 20`. That's a direct index seek, constant time regardless of how deep you are. The tradeoff is that you lose the ability to jump to page N — you can only go forward sequentially. That's fine for feeds and infinite scroll but not for admin UIs where users type '500' in a page box."

> *The phrase "index seek vs index scan" signals you understand database internals, not just API design.*

**Gotcha follow-up they'll ask:** *"What happens with cursor pagination if the sort column isn't unique?"*

> "If you sort by `created_at` alone and two records have the same timestamp, the cursor is ambiguous — you might skip records or return duplicates. The fix is to always compose the cursor from two fields: the sort column plus a unique tiebreaker, typically the primary key. So your cursor encodes `(created_at, id)` and your `WHERE` clause is `WHERE (created_at, id) < (?, ?)` using tuple comparison. This guarantees a unique, stable position in the result set."

---

##### Q2 — Tradeoff Question
**"When would you choose offset pagination over cursor pagination?"**

**One-line answer:** Offset pagination is the right choice when users need to jump to arbitrary pages, when datasets are small enough that scan cost doesn't matter, or when building admin interfaces where page numbers are meaningful.

**Full answer to give in an interview:**

> "Cursor pagination gives up random access — you can't say 'jump to page 47.' That's a real UX limitation for certain interfaces. Admin dashboards, CMS tools, and data-export flows often need to let users navigate to a specific page number, or show 'page 12 of 40.' For those, offset pagination is more appropriate, and you accept the performance cost because dataset sizes are controlled and infrequently hit the scale where offset becomes a problem. For public-facing APIs — news feeds, social timelines, product listings, any infinite-scroll UI — cursor or keyset pagination is better. They're stable under concurrent writes (an insert on page 2 won't push items off page 3), and they don't degrade with depth. I'd also note: many teams start with offset and add cursor pagination later as an opt-in, keeping backward compatibility."

> *Saying 'stable under concurrent writes' is a detail most candidates miss — it's a strong signal you've thought about production data conditions.*

**Gotcha follow-up they'll ask:** *"How do you paginate a search result with filters and sorting?"*

> "The cursor must encode the full sort state. If the client is sorting by `price ASC` then the cursor encodes the last item's `price` and `id`. If they switch sort order mid-session, the cursor from the previous sort is invalid — it encodes a position in a different ordered sequence. You should either reset pagination on sort/filter change, or use opaque cursors that embed the filter state and validate on decode. Most production APIs simply document that changing filter parameters resets to the first page."

---

##### Q3 — Design Scenario
**"Design pagination for a high-traffic product listing API that supports filtering and sorting."**

**One-line answer:** Use keyset pagination with composite cursors encoding the sort key and ID, an opaque base64-encoded token for clients, and document that filter or sort changes reset to page one.

**Full answer to give in an interview:**

> "For a high-traffic product listing, I'd use keyset pagination. The default sort is relevance score descending with product ID as tiebreaker. The cursor encodes `(score, product_id)` as a base64 JSON token — opaque to clients, decoded server-side. The query becomes `WHERE (score, id) < (last_score, last_id)`. For different sort orders like price or rating, the cursor encodes that column plus ID. Each response returns `next_cursor`, `has_more`, and `page_size` — no total count, because counting millions of rows on every request is expensive. On the filter side, if the user changes category or price range, the client drops the cursor and starts fresh. I'd also cache the first page aggressively — it's the most requested — and use read replicas for all pagination queries to keep write latency unaffected."

> *Mentioning opaque cursors (hiding the internal sort key) and read replicas shows you're thinking about production, not just the algorithm.*

---

> **Common Mistake — Returning total count with cursor pagination:** Fetching `COUNT(*)` on a filtered table of millions of rows on every paginated request is expensive and often defeats the performance gains of cursor pagination. Return `has_more` instead and document that total counts are unavailable — most UX patterns (infinite scroll, load-more buttons) don't need it.

---

**Quick Revision (one line):**
Offset pagination degrades with depth due to database scan cost — replace it with cursor or keyset pagination, which converts `OFFSET N` into a `WHERE key < last_seen` index seek that stays fast regardless of depth.

---

## Topic 8: Request and Response Design

---

#### The Idea

Imagine two people having a conversation through a wall, passing notes. If one person writes "usr_nm" and the other expects "username," or one sends a date as "15/01/2024" and the other expects "2024-01-15," they'll constantly misunderstand each other. API request and response design is about establishing a clear, consistent "language" between client and server — field names, date formats, nesting depth, and how to ask for subsets of data.

Good design here is about predictability. When a developer uses your API for the first time, they should be able to guess how a new endpoint works from the patterns they've already learned. If your user endpoint returns `created_at`, your order endpoint should also return `created_at`, not `createdDate` or `date_created`.

The rules in this area are widely agreed upon across the industry (Google API design guide, Stripe, GitHub) and interviewers expect you to know them — not just as opinions but as specific, justified conventions.

---

#### How It Works

**Naming conventions:**

```
JSON field names:  snake_case       ("created_at", "user_id", "first_name")
URL path segments: kebab-case       (/user-profiles, /order-items)
Query parameters:  snake_case       (?sort_by=created_at&page_size=20)
HTTP headers:      Kebab-Case       (X-Request-Id, Content-Type)
```

Using `camelCase` in JSON (JavaScript convention) is common but inconsistent across languages. `snake_case` is the most portable and is used by Stripe, GitHub, and Google.

**Resource nesting — max 2 levels:**

```
Good:
GET /users/{userId}/orders          ← orders owned by a user
GET /orders/{orderId}/items         ← items in an order

Avoid:
GET /users/{userId}/orders/{orderId}/items/{itemId}/reviews
                                    ← too deep, hard to cache, brittle URLs
```

For deeply nested resources, use top-level endpoints with filter parameters:

```
GET /reviews?order_item_id=789      ← flatter, more composable
```

**Standardised query parameters:**

```
Filtering:      ?status=active&created_after=2024-01-01
Sorting:        ?sort_by=created_at&sort_order=desc
Pagination:     ?cursor=<token>&page_size=20
Field selection: ?fields=id,name,email     ← return only specified fields
Search:         ?q=laptop                  ← full-text search
```

**Response envelope — always wrap collections:**

```
{
  "data": [ ...items... ],
  "pagination": { "next_cursor": "...", "has_more": true },
  "meta": { "request_id": "abc-123", "api_version": "2024-01" }
}
```

Wrapping gives you room to add metadata later without breaking clients who read `response.data`.

**Null vs absent fields:** explicitly return `null` for optional fields that exist but have no value — don't omit them silently. Omitting a field is ambiguous (does it not exist, or is it null?). Clients can distinguish `null` from missing.

**Dates and times:** always use ISO 8601 with UTC timezone: `"2024-01-15T10:30:00Z"`. Never use Unix timestamps in JSON (unreadable) or locale-specific formats.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What naming conventions should REST APIs follow, and why does consistency matter?"**

**One-line answer:** Use `snake_case` for JSON fields, `kebab-case` for URL paths, ISO 8601 for dates, and apply the same convention across every endpoint so clients can write generic tooling.

**Full answer to give in an interview:**

> "The most important thing is consistency — pick a convention and apply it everywhere. For JSON field names, `snake_case` is the industry standard used by Stripe, GitHub, and Google: `created_at`, `user_id`, `first_name`. For URL paths, `kebab-case` is conventional: `/order-items`, `/user-profiles`. For dates, always ISO 8601 with UTC: `2024-01-15T10:30:00Z` — never locale-specific formats like `15/01/2024` or Unix timestamps in JSON responses. Why does consistency matter? Because it lets clients write generic serialisation code. If one endpoint returns `createdAt` and another returns `created_at`, client code needs special-case logic for each. It makes auto-generated API clients unreliable and makes the API feel unfinished. The concrete cost of inconsistency is developer time and bugs at integration points."

> *Naming specific companies that use snake_case (Stripe, GitHub) adds credibility. Interviewers notice when candidates can ground answers in real precedent.*

**Gotcha follow-up they'll ask:** *"How deep should resource nesting go in URLs?"*

> "Two levels maximum. `/users/{userId}/orders` is fine — it expresses ownership clearly. Going deeper, like `/users/{userId}/orders/{orderId}/items/{itemId}/reviews`, creates brittle URLs, makes caching harder (you can't cache the reviews resource independently of the user path), and breaks if the ownership hierarchy changes. For deeply nested resources, use top-level endpoints with filter parameters: `GET /reviews?order_item_id=789`. This is flatter, more composable, and more cacheable."

---

##### Q2 — Tradeoff Question
**"Should you return null fields or omit them from the response?"**

**One-line answer:** Return null explicitly rather than omitting fields — omission is ambiguous between 'field doesn't exist' and 'field has no value,' which forces clients to write defensive checks for both.

**Full answer to give in an interview:**

> "If a field is part of the schema but has no value, return it as null: `'middle_name': null`. If you omit it silently, the client can't distinguish two cases: the field exists but is empty, or the field doesn't exist on this resource type at all. That forces clients to use defensive null-safe access everywhere and makes documentation harder — you'd have to specify which fields might disappear. The exception is truly optional fields that are absent by design in specific resource variants — but even then, I'd prefer an explicit null to omission. For API versioning, always adding new nullable fields rather than removing existing ones lets existing clients continue working without changes."

> *The distinction between 'null value' and 'absent field' is a subtlety that senior engineers care about. Raising it unprompted signals API design experience.*

**Gotcha follow-up they'll ask:** *"How do you handle boolean flags that need to evolve into enum values later?"*

> "Start with an enum string rather than a boolean, even if today there are only two states. `'status': 'active'` is far easier to extend to `'status': 'active' | 'suspended' | 'pending'` than changing `'is_active': true/false`. Changing a boolean to an enum is a breaking change. Using an enum string from day one means new states are just new valid values — existing clients that don't recognise the new value can handle it generically (treat unknown as 'other') without breaking."

---

##### Q3 — Design Scenario
**"Design the request and response shape for a product search endpoint."**

**One-line answer:** Use standardised query parameters for filtering, sorting, and pagination; wrap the response in a data envelope with pagination metadata; use snake_case throughout with ISO 8601 dates.

**Full answer to give in an interview:**

> "The request: `GET /products?q=laptop&category=electronics&min_price=500&max_price=2000&sort_by=price&sort_order=asc&cursor=<token>&page_size=20`. All snake_case, all predictable. The response is a wrapped envelope: a `data` array of product objects, a `pagination` object with `next_cursor` and `has_more`, and a `meta` object with `request_id` for tracing. Each product in the data array has consistent field names — `id`, `name`, `price_cents` (using cents to avoid float precision issues), `created_at` as ISO 8601 UTC, `category`, `status` as an enum string. Optional fields like `discount_price_cents` are returned as null when not applicable, never omitted. For field selection, support a `fields` query parameter so mobile clients can request `?fields=id,name,price_cents` and skip heavy fields like `description`. This keeps response payloads small on bandwidth-constrained clients."

> *Using `price_cents` (integer) instead of `price` (float) is a production detail that signals you've dealt with real money-handling bugs.*

---

> **Common Mistake — Inconsistent field naming across endpoints:** Having `userId` on one endpoint and `user_id` on another, or `createdAt` in one resource and `created_at` in another, forces clients to write custom mapping for every endpoint. A single naming decision applied everywhere, enforced by a serialisation layer, costs almost nothing and saves clients enormous integration pain.

---

**Quick Revision (one line):**
Use `snake_case` for JSON fields, ISO 8601 UTC for dates, max 2 levels of URL nesting, standardised query parameters for filtering/sorting/pagination, and always wrap collection responses in a `data` envelope.

---

## Topic 9: API Rate Limiting

---

#### The Idea

Imagine a restaurant with 10 tables. If 200 people try to walk in at once, the restaurant collapses — staff can't keep up, food quality drops, and everyone has a bad experience. A good restaurant puts a bouncer at the door: only a controlled number of people can enter at a time, and everyone else waits or is turned away politely. API rate limiting is that bouncer — it controls how many requests a client can make within a time window, protecting the server from being overwhelmed.

Rate limiting serves three goals: protecting backend systems from traffic spikes (including accidental ones from buggy clients), ensuring fair usage among many clients (one client can't monopolise capacity), and preventing abuse (scrapers, credential stuffing attacks, DDoS). Without it, a single misbehaving client can degrade the service for everyone.

The challenge is choosing the right algorithm. Too strict, and legitimate users hit limits during normal usage bursts. Too lenient, and the limits don't actually protect anything. The algorithms differ mainly in how they handle burst traffic and boundary effects.

---

#### How It Works

Three core algorithms:

**Fixed window:** count requests in each fixed time window (e.g., 0-60s, 60-120s). Reset counter at the window boundary.

```
window_start = floor(now / window_size) * window_size
key = "rate_limit:{client_id}:{window_start}"
count = INCR key
EXPIRE key window_size
if count > limit: reject(429)
```

Problem: a client can send 100 requests in the last second of window 1 and 100 in the first second of window 2 — 200 requests in a 2-second span, double the intended limit. This is the "boundary spike" problem.

**Sliding window:** count requests in the last N seconds from the current moment, not from a fixed boundary.

```
now = current_timestamp_ms
window_start = now - window_size_ms
ZREMRANGEBYSCORE key 0 window_start     # remove old entries
count = ZCARD key
if count >= limit: reject(429)
ZADD key now now                         # record this request
EXPIRE key window_size_seconds
```

Eliminates boundary spikes. More memory-intensive (stores each request timestamp).

**Token bucket:** tokens accumulate at a fixed rate up to a maximum capacity. Each request consumes one token. Allows bursting up to the bucket capacity.

```
tokens = min(capacity, last_tokens + (elapsed_seconds * refill_rate))
if tokens < 1: reject(429)
tokens = tokens - 1
store(client_id, tokens, now)
```

| | Fixed Window | Sliding Window | Token Bucket |
|---|---|---|---|
| **Burst handling** | Allows 2x at boundary | Smooth, no spikes | Allows burst up to capacity |
| **Memory** | Low (one counter/window) | Higher (timestamps per request) | Low (two values per client) |
| **Implementation** | Simplest | Medium | Medium |
| **Boundary spike** | Yes | No | No |
| **Real-world use** | Basic APIs | High-precision | Most production APIs |
| **Allows gradual burst** | No | No | Yes |

Communicating limits to clients — always include these response headers:

```
X-RateLimit-Limit: 1000          # max requests allowed
X-RateLimit-Remaining: 743       # requests left in current window
X-RateLimit-Reset: 1705312800    # Unix timestamp when window resets
Retry-After: 30                  # seconds until client should retry (on 429)
```

For distributed systems, rate limit state must live in Redis — local in-memory state doesn't work when requests are spread across multiple server instances. Use Lua scripts in Redis to make the check-and-increment atomic:

```lua
-- Lua script run atomically in Redis
local key = KEYS[1]
local limit = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local now = tonumber(ARGV[3])

local count = redis.call('INCR', key)
if count == 1 then
  redis.call('EXPIRE', key, window)
end
if count > limit then
  return 0  -- rejected
end
return 1    -- allowed
```

The must-memorise gotcha: without atomic check-and-increment, two concurrent requests can both read count=99, both increment to 100, and both pass a limit of 100 — letting through 101 requests. The Lua script runs as a single Redis transaction, preventing this race.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Explain the token bucket algorithm and why it's preferred over fixed window rate limiting."**

**One-line answer:** Token bucket accumulates tokens at a fixed rate up to a maximum, allowing natural bursting while still enforcing a long-term average rate — unlike fixed window, which creates boundary spikes and doesn't allow legitimate short bursts.

**Full answer to give in an interview:**

> "In the token bucket algorithm, each client has a 'bucket' that holds tokens up to a maximum capacity. Tokens are added at a fixed refill rate — say, 10 tokens per second. Each API request consumes one token. If the bucket is empty, the request is rejected with a 429. If you haven't made requests for a while, tokens accumulate, so when you do make a burst of requests you have capacity for it. This matches real usage patterns — a mobile app might make 0 requests for 10 seconds then fire 50 in quick succession when the user navigates. Fixed window would reject half of those; token bucket allows it because the bucket built up capacity during the quiet period. Fixed window also has the 'boundary spike' problem: a client can send max requests at the end of one window and immediately again at the start of the next, getting double the intended rate for a brief period. Token bucket has none of this — it enforces the long-term average rate while smoothing out how requests are distributed in time."

> *The phrase 'matches real usage patterns' is key — it shows you're thinking about client experience, not just algorithm correctness.*

**Gotcha follow-up they'll ask:** *"How do you implement rate limiting in a distributed system where requests hit different servers?"*

> "You can't use in-process memory — each server would have its own counter and they'd be unaware of each other, so the effective limit would be `limit × number_of_servers`. The solution is centralised state in Redis. Every server checks and updates the same Redis key. The critical detail is atomicity: you must use a Lua script or Redis transaction to make the read-check-increment atomic. Without it, two servers can both read the same counter value simultaneously, both determine they're under the limit, and both increment — creating a race condition that lets through more requests than the limit allows."

---

##### Q2 — Tradeoff Question
**"What should you rate limit on — IP address, API key, or user ID?"**

**One-line answer:** Use API keys as the primary rate-limit identifier for authenticated APIs; add IP-based limits as a secondary layer for unauthenticated endpoints and authentication attempts.

**Full answer to give in an interview:**

> "IP addresses are unreliable — many users share IPs through NAT, corporate proxies, or mobile carrier gateways. Rate limiting on IP can accidentally block an entire office or ISP. For authenticated APIs, the right identifier is the API key or authenticated user ID. This gives each client their own bucket, is fair, and lets you set different limits per tier — free tier gets 1,000 requests/day, paid tier gets 100,000. For unauthenticated endpoints — login, sign-up, password reset — you have no API key, so IP-based limiting is the right tool there, combined with CAPTCHA for abuse patterns. A layered approach is best: per-API-key limits for normal usage, per-IP limits as a backstop for unauthenticated flows, and a global circuit breaker that protects the server if total traffic spikes regardless of the source."

> *Mentioning 'different limits per tier' shows you're thinking about real product design, not just security.*

**Gotcha follow-up they'll ask:** *"What headers should you return with a 429 Too Many Requests response?"*

> "At minimum: `X-RateLimit-Limit` (the configured limit), `X-RateLimit-Remaining` (how many requests are left in the current window — which is 0 when returning 429), `X-RateLimit-Reset` (Unix timestamp when the window resets and the client can retry), and `Retry-After` (seconds until retry is safe — this is the most actionable one for client retry logic). The `Retry-After` header is defined in RFC 7231 and allows well-behaved clients to implement automatic backoff correctly."

---

##### Q3 — Design Scenario
**"Design rate limiting for a public REST API that has both free and paid tiers."**

**One-line answer:** Use per-API-key token buckets stored in Redis with tier-specific limits, enforce atomically with Lua scripts, communicate state via X-RateLimit headers, and return RFC 7807 problem details on 429.

**Full answer to give in an interview:**

> "I'd key rate limit state on the API key, stored in Redis. Each key has a tier-specific configuration: free tier gets 100 requests per minute with burst capacity of 20 (token bucket capacity), paid tier gets 5,000 per minute with burst of 500. The check happens in a Lua script to guarantee atomicity across distributed servers. On every response — not just 429s — I'd include `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `X-RateLimit-Reset` so clients can track their usage and back off before hitting the limit. When the limit is exceeded, return 429 with an RFC 7807 body including `Retry-After` in both the header and the body's `detail` field. I'd also implement a global server-level circuit breaker that activates if total request rate hits a threshold, regardless of individual client limits — this protects against scenarios where many clients legitimately hit their limits simultaneously and overwhelm the system. For the Redis layer, I'd use a Redis cluster with sentinel for HA, and fail open if Redis is unavailable — reject dropping requests due to rate-limit infrastructure failure is worse than momentarily allowing through extra traffic."

> *'Fail open if Redis is unavailable' is an advanced operational detail — it shows you've thought about what happens when your infrastructure components fail, not just the happy path.*

---

> **Common Mistake — Not including rate limit headers on successful responses:** Clients can't implement proactive backoff if they only see headers on 429 responses. Including `X-RateLimit-Remaining` on every response lets well-behaved clients slow down gracefully before they hit the wall, reducing the number of rejected requests and improving overall API stability.

---

**Quick Revision (one line):**
Token bucket allows natural bursting while enforcing a long-term average rate — implement it with atomic Redis operations, communicate limit state via `X-RateLimit-*` headers on every response, and return 429 with `Retry-After` when the limit is exceeded.

---

## Topic 10: Content Negotiation and Media Types

---

#### The Idea

Imagine you walk into a restaurant and ask "do you have anything vegetarian?" The waiter checks the menu, says "yes, we have pasta," and brings it to you. You didn't have to order a specific dish by name — you stated your preference, and the kitchen adapted. HTTP content negotiation works the same way: the client tells the server what formats it can handle, and the server picks the best match and tells the client what it's returning.

This matters because different clients have different needs. A browser might want HTML. A mobile app wants compact JSON. A legacy enterprise system might need XML. Rather than building separate endpoints for each format, the server negotiates format based on HTTP headers.

Content negotiation also solves API versioning elegantly. Instead of cluttering your URLs with `/v2/users` or query parameters like `?version=2`, you can encode the version in the media type itself: `Accept: application/vnd.myapi.v2+json`. This keeps URLs clean and makes versioning a proper part of the HTTP protocol.

---

#### How It Works

Two headers drive content negotiation:

**`Accept` header (client → server):** "Here are the formats I can handle, in priority order."

```
Accept: application/json                          # only JSON
Accept: application/json, application/xml         # JSON or XML, JSON preferred
Accept: application/json;q=0.9, text/html;q=0.5  # JSON strongly preferred
Accept: */*                                       # anything is fine
```

The `q` value (quality factor) ranges from 0 to 1. Higher means more preferred. If omitted, it defaults to 1.0.

**`Content-Type` header (server → client, or client → server):** "This is the actual format of this body."

```
Content-Type: application/json
Content-Type: application/xml
Content-Type: multipart/form-data; boundary=----abc123
Content-Type: application/problem+json    ← RFC 7807 error response
```

When the client sends a request body (POST/PUT/PATCH), it uses `Content-Type` to describe that body. When the server responds, it uses `Content-Type` to describe the response body.

Server-side negotiation logic:

```
parse Accept header into list of (media_type, q_value) pairs
sort by q_value descending
for each acceptable media_type in order:
  if server supports media_type:
    set Content-Type to media_type
    serialize response body in that format
    return response
return 406 Not Acceptable   ← server can't produce any acceptable format
```

**Versioned media types (`vnd.*`):**

```
Accept: application/vnd.myapi.v2+json
```

The `vnd.` prefix means "vendor-specific." The format is:
`application/vnd.{vendor}.{resource-type}.v{version}+{base-format}`

```
application/vnd.github.v3+json       ← GitHub API v3
application/vnd.myapi.orders.v2+json ← orders resource, v2
```

This lets clients request a specific API version via the Accept header. The server returns `Content-Type: application/vnd.myapi.v2+json` to confirm the version used. Old clients continue working because they keep sending the old `Accept` header.

**Status codes for negotiation failures:**

```
406 Not Acceptable       ← server cannot produce a format matching Accept
415 Unsupported Media Type ← server cannot parse the Content-Type of the request body
```

The must-memorise gotcha: use `application/problem+json` (not `application/json`) as the `Content-Type` for RFC 7807 error responses. This signals to clients that the body is a standardised error payload, not a normal resource response — allowing generic error-handling middleware to activate on this content type.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"How does HTTP content negotiation work? Explain the Accept and Content-Type headers."**

**One-line answer:** The client uses the `Accept` header to specify what formats it can handle (with priority via q-values), and the server uses `Content-Type` to declare the format of the body it actually returns — returning 406 if it can't satisfy the client's preferences.

**Full answer to give in an interview:**

> "Content negotiation is a built-in HTTP mechanism for agreeing on data format without hardcoding it into the URL. The client sends an `Accept` header listing the media types it accepts, optionally with q-values — quality factors from 0 to 1 — that express preference. For example, `Accept: application/json;q=0.9, application/xml;q=0.5` means 'I strongly prefer JSON, but I'll take XML.' The server parses this list, sorts by q-value, and picks the first format it can produce. It then serialises the response in that format and sets the `Content-Type` header to declare what it chose. If the server can't produce any of the acceptable formats, it returns 406 Not Acceptable. The `Content-Type` header also goes the other way — when a client sends a request body in a POST or PUT, it sets `Content-Type` to tell the server how to parse it. If the server doesn't support that format, it returns 415 Unsupported Media Type."

> *Walking through both directions of `Content-Type` — request body and response body — shows you understand the full protocol, not just one side.*

**Gotcha follow-up they'll ask:** *"What's the difference between `application/json` and `application/problem+json`?"*

> "`application/json` is the generic JSON media type. `application/problem+json` is defined by RFC 7807 and signals specifically that the body is a standardised error object with `type`, `title`, `status`, `detail`, and `instance` fields. The distinction matters for clients: a client that receives `application/json` doesn't know whether it's getting a normal resource or an error response. A client that receives `application/problem+json` knows it's an error and can route it to generic error-handling logic. This is why error responses should always use `application/problem+json` even when the body happens to be valid JSON."

---

##### Q2 — Tradeoff Question
**"Compare versioning via URL path (/v2/users) versus versioned media types (application/vnd.api.v2+json). Which would you choose and why?"**

**One-line answer:** URL versioning is simpler, more visible, and easier to route — prefer it for most APIs; versioned media types are more semantically correct and keep URLs clean, but add complexity that's only justified for large APIs with sophisticated clients.

**Full answer to give in an interview:**

> "URL versioning — putting `/v2/` in the path — is the approach most APIs use in practice, including Stripe, Twilio, and most REST APIs you'll encounter. It's extremely visible (the version is obvious in every log, every bookmark, every curl command), trivial to route at the load balancer or API gateway level, and easy to explain to developers. The downside is that URLs are supposed to identify resources, not protocol versions — `/v2/users/123` and `/v1/users/123` are arguably the same resource, just in different representations. Versioned media types via the `Accept` header are more semantically correct from a REST-purity standpoint. GitHub uses this. The URL stays `/users/123` forever; the version is negotiated in the header. This is cleaner for very long-lived APIs. The practical downside: most HTTP tooling, proxies, and caches were built around URL-based routing. Some API gateways can't route on `Accept` header without custom configuration. And developer experience is harder — you can't just change a URL in a browser to test a different version. My default is URL versioning for simplicity. I'd consider header-based versioning only for a large public API where URL cleanliness matters and I have sophisticated clients."

> *Grounding the answer in what major APIs actually do (Stripe, GitHub) makes it concrete and shows real-world awareness.*

**Gotcha follow-up they'll ask:** *"What should a server return if a client sends `Accept: application/xml` but the API only supports JSON?"*

> "406 Not Acceptable — the server cannot produce a response matching the client's stated acceptable formats. The response body should explain what formats are supported, ideally in a format the client can still parse (which is a slight paradox — you can return the 406 body as text/plain or application/json and note that the server supports `application/json`). In practice, many APIs ignore the `Accept` header and always return JSON — this is technically wrong but pragmatically common. A well-behaved API should honour the standard."

---

##### Q3 — Design Scenario
**"How would you design content negotiation for a public API that needs to support both JSON and XML clients, plus API versioning?"**

**One-line answer:** Support `Accept: application/json` and `Accept: application/xml` for format negotiation, use URL versioning for the primary version path, and add versioned media type support as an optional enhancement for sophisticated clients.

**Full answer to give in an interview:**

> "For format negotiation, I'd register two serialisers on every endpoint — JSON and XML. The server inspects the `Accept` header: `application/json` gets a JSON response, `application/xml` gets XML. Default (no `Accept` header or `Accept: */*`) returns JSON. For unsupported formats, return 406 with a body that lists the supported types. For versioning, I'd use URL versioning as the primary mechanism — `/v1/`, `/v2/` — because it's the most operationally visible and the most widely supported by API gateways. I'd additionally support versioned media types like `Accept: application/vnd.myapi.v2+json` for clients that prefer header-based versioning. On the `Content-Type` side: all success responses mirror the `Accept` format chosen; all error responses always use `application/problem+json` regardless of the negotiated format, because RFC 7807 error handling is format-specific to JSON. For request bodies, I'd validate the incoming `Content-Type` header and return 415 if it's a format I don't support."

> *The note that error responses always use `application/problem+json` even for XML-preferring clients is a nuanced detail that separates a thorough answer from a surface-level one.*

---

> **Common Mistake — Ignoring the Accept header and always returning JSON:** This breaks clients that explicitly request XML or other formats, returns 200 with content the client can't parse, and makes the API non-compliant with HTTP. It also means error responses get `Content-Type: application/json` instead of `application/problem+json`, breaking RFC 7807 error handling. A proper content negotiation layer costs little to implement and makes the API a correct HTTP citizen.

---

**Quick Revision (one line):**
The client's `Accept` header declares preferred formats with q-value priorities; the server matches and responds with `Content-Type` confirming the chosen format; return 406 for unsupported formats and always use `application/problem+json` for error responses regardless of the negotiated format.

---

## Topic 11: HTTP Caching

---

#### The Idea

Imagine you order a pizza every Friday. The first week, you call the shop, they make it fresh, and deliver it. The second week, you call again — but this time the shop says "We still have your order from last week, nothing's changed, you can just reheat the one you have." You save time, the shop saves effort, and the pizza is just as good. HTTP caching works the same way: a client (browser, mobile app) saves a copy of a server's response, and on the next request asks "has anything changed?" — if not, it uses its saved copy.

The server controls this behaviour by sending `Cache-Control` headers with every response. These headers tell the browser, any CDN sitting in the middle, and any proxy exactly who is allowed to cache the response, and for how long. A CDN (Content Delivery Network) like Cloudflare or AWS CloudFront acts as a regional middleman — it caches your responses at servers close to your users, so a user in Tokyo doesn't have to wait for a response from a server in Virginia.

The second mechanism is **conditional requests**. Even when a cached response has "expired," the client doesn't throw it away — instead it sends the server a fingerprint of what it has (an ETag or a Last-Modified timestamp) and asks "is this still current?" If it is, the server replies `304 Not Modified` with no body, saving all the bandwidth of retransmitting the content. This is the heartbeat of efficient HTTP communication.

---

#### How It Works

**Cache-Control directives — what they mean and when to use them:**

```
max-age=3600          → Cache for 3600 seconds (browser + CDN)
s-maxage=3600         → Override max-age for shared caches (CDN only)
no-cache              → You MAY cache, but revalidate with server before every use
                        (NOT "don't cache" — common misconception)
no-store              → Never cache; never write to disk (banking, payments)
private               → Browser may cache; CDN/proxy must NOT (user-specific data)
public                → Any cache may store this (shared public data)
must-revalidate       → Once stale, you must revalidate; no serving stale copies
immutable             → Content at this URL never changes; never revalidate
stale-while-revalidate=60 → Serve stale for 60s while fetching fresh in background
```

**Cache hierarchy (request travels through each layer in order):**

```
Browser cache
  → Service Worker (if installed)
    → CDN edge cache (geographically close to user)
      → CDN origin shield (single point of contact for the origin)
        → Origin server
```

**ETag conditional request flow — the must-memorise gotcha:**

The ETag (Entity Tag) is a fingerprint — typically a hash of the response body — that the server assigns to a resource version. The conditional request flow eliminates bandwidth when content hasn't changed:

```java
// Step 1: First request — server returns resource + ETag
GET /products/123
→ 200 OK
   ETag: "v3-abc123def456"
   Cache-Control: private, max-age=300
   Body: { ...product data... }

// Step 2: Client caches response AND the ETag

// Step 3: Cache expires (or no-cache directive). Client sends conditional request:
GET /products/123
If-None-Match: "v3-abc123def456"

// Step 4a: Resource unchanged → server sends 304, NO body
→ 304 Not Modified
   ETag: "v3-abc123def456"
   // Client uses its cached copy. Zero bandwidth for the body.

// Step 4b: Resource changed → server sends full response with new ETag
→ 200 OK
   ETag: "v4-xyz789ghi012"
   Body: { ...updated product data... }
```

**The gotcha:** ETag takes precedence over `Last-Modified`. Always check `If-None-Match` first. `Last-Modified` / `If-Modified-Since` is the fallback — it uses timestamps, which have 1-second granularity and are vulnerable to clock drift between servers.

**Resource type → correct Cache-Control pattern:**

```
HTML pages:               no-cache
  (revalidate every time, but use cached copy on 304)

User-specific API data:   private, no-cache  OR  private, max-age=60

Static assets             public, max-age=31536000, immutable
(hashed filenames):       (URL changes on content change, so cache forever)

Public API data           public, s-maxage=300, stale-while-revalidate=60
(product catalog):        (CDN caches 5 min; serve stale while refreshing)

Sensitive data            no-store
(payments, banking):      (never touch any cache layer)
```

**Vary header — critical for correctness:**

```
Vary: Accept-Encoding  → keep separate cached copies for gzip vs plain
Vary: Accept           → keep separate copies for JSON vs XML responses
Vary: Authorization    → effectively makes response private (CDNs won't cache it)
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check: no-cache vs no-store
**"What is the difference between `no-cache` and `no-store`? Which would you use for a banking app?"**

**One-line answer:** `no-cache` allows caching but requires revalidation before use; `no-store` prevents caching entirely — use `no-store` for sensitive banking data.

**Full answer to give in an interview:**

> "These two directives are the most commonly confused in HTTP caching. `no-cache` is misleading by name — it does NOT mean 'don't cache.' It means 'you may store a cached copy, but you must revalidate it with the server before serving it to the user.' So the browser still writes the response to disk and sends a conditional request with `If-None-Match` next time, potentially getting a `304 Not Modified` and saving bandwidth. `no-store`, on the other hand, means the response must never be written to any cache — not disk, not memory. For a banking application showing account balances or transaction history, I'd use `no-store` because even a briefly cached balance could show stale data, and storing financial data in a shared or compromised cache is a security risk. For a page that changes frequently but isn't sensitive — like a news homepage — `no-cache` is the right choice because it still benefits from the `304` optimisation."

> *Pause after the one-liner. The interviewer will nod if they want the elaboration. Don't dump everything at once.*

**Gotcha follow-up they'll ask:** *"If `no-cache` still caches the response, what's the point over just `max-age=0`?"*

> "`max-age=0` means the response is immediately stale, so caches should revalidate before serving it — which in practice behaves the same as `no-cache` for most caches. The semantic difference is that `no-cache` is a more explicit instruction that was designed specifically to mandate revalidation, whereas `max-age=0` is a TTL that just happens to expire immediately. Some older caches and CDNs handle them slightly differently. For clarity of intent, use `no-cache` when you want revalidation behaviour."

---

##### Q2 — Design Scenario: Caching strategy for a product catalog API
**"You're designing a public product catalog API served through a CDN. Products change a few times a day. How do you set up caching?"**

**One-line answer:** Use `public, s-maxage=300, stale-while-revalidate=60` with ETag support so the CDN caches aggressively while clients get near-fresh data.

**Full answer to give in an interview:**

> "I'd set `Cache-Control: public, s-maxage=300, stale-while-revalidate=60` on catalog responses. `public` tells the CDN it's allowed to cache this. `s-maxage=300` tells the CDN to keep it for 5 minutes — shared-cache-only, so individual browsers use the default `max-age` if I set one, or revalidate if I don't. `stale-while-revalidate=60` means that when the 5 minutes expires, the CDN can serve the stale cached copy for an extra 60 seconds while it fetches a fresh copy from the origin in the background — this eliminates the thundering herd problem where every CDN node suddenly stampedes the origin at the same moment the cache expires. I'd also add ETag support on the origin server: when the CDN does revalidate, it sends `If-None-Match`, and if the catalog hasn't changed, the origin returns `304 Not Modified` with no body, saving bandwidth between CDN and origin. For cache invalidation when a product is updated, I'd either use a version in the URL path — `/api/v1/catalog/v42` — or call the CDN's purge API to invalidate the specific cache key."

> *This answer shows you understand the full cache hierarchy, not just browser caching.*

**Gotcha follow-up they'll ask:** *"How do you handle cache invalidation when a product price changes immediately?"*

> "Pure TTL-based caching can't guarantee immediate invalidation. Options: (1) Use the CDN's cache purge API — AWS CloudFront, Cloudflare, and Fastly all support programmatic purge — triggered when a product is updated. (2) Use cache keys that include a version or hash, and change the URL when content changes — so the old cache entry simply becomes orphaned. (3) For price-sensitive endpoints, use a shorter `s-maxage` (30–60 seconds) and accept eventual consistency within that window. In practice, most product catalogs tolerate 30–60 second staleness, so a short TTL plus purge-on-write covers 99% of cases."

---

##### Q3 — Tradeoff: ETag vs Last-Modified
**"Why would you prefer ETags over Last-Modified for conditional requests?"**

**One-line answer:** ETags are more precise — they work at sub-second granularity and aren't affected by server clock drift, which can cause Last-Modified to give wrong answers.

**Full answer to give in an interview:**

> "Both ETags and Last-Modified enable conditional requests — the client sends a fingerprint of its cached copy, the server checks if it's still current, and returns `304 Not Modified` if nothing has changed. The difference is in accuracy. `Last-Modified` uses a timestamp with one-second granularity, so if a resource is updated twice within the same second, the second update is invisible — the server still sees the same modification time and incorrectly returns `304`. It's also vulnerable to clock drift in distributed systems where multiple origin servers may have slightly different system times. ETags are opaque identifiers — typically a hash of the response body or a version number — so they change precisely when the content changes, regardless of time. The downside of ETags is that they're harder to generate correctly in load-balanced environments: every server must produce the same ETag for the same content version, which means the ETag computation must be deterministic and shared (e.g., based on a database version number rather than server-local file metadata)."

> *Strong vs weak ETags is a natural follow-on: strong (`"abc123"`) means byte-for-byte identical; weak (`W/"abc123"`) means semantically equivalent.*

---

> **Common Mistake — Confusing `no-cache` with `no-store`:** Using `no-cache` for banking data thinking it prevents caching — it doesn't. The response is still stored; it's just revalidated before use. Use `no-store` for genuinely sensitive data. Getting this wrong in a fintech interview is a significant red flag.

---

**Quick Revision (one line):**
Cache-Control directives (max-age, s-maxage, no-cache means "revalidate", no-store means "never cache", private, immutable) control who caches what for how long; ETags + If-None-Match enable 304 responses that save bandwidth; stale-while-revalidate eliminates thundering herd on TTL expiry.

---

## Topic 12: API Security Basics

---

#### The Idea

Think of a bank. The front door requires a key card (authentication — proving who you are). Once inside, your role determines which rooms you can enter: a teller can access the vault corridor but not the executive suite (authorization — what you're allowed to do). The building also has guards who check every bag entering for weapons (input validation), and the windows are one-way glass so passersby can't see in (HTTPS encryption). API security is exactly this layered physical security model applied to software.

The most common class of API security failure isn't sophisticated cryptography attacks — it's developers forgetting to check whether the authenticated user actually owns the resource they're requesting. If user A is authenticated and requests `/api/orders/12345`, does the server check that order 12345 belongs to user A? Surprisingly often, it doesn't. This is called BOLA — Broken Object Level Authorization — and it's the number-one item on the OWASP API Security Top 10 because it's both devastatingly common and devastatingly impactful.

CORS (Cross-Origin Resource Sharing) is the browser's same-origin policy in action. Browsers block JavaScript on `evil.com` from calling `api.bank.com` — but APIs can opt in to specific trusted origins via CORS headers. The trap is setting `Access-Control-Allow-Origin: *` (allow everyone) while also sending `Access-Control-Allow-Credentials: true` — this combination lets any website make authenticated requests to your API on behalf of your users. That's a security hole, not a configuration shortcut.

---

#### How It Works

**The security layers in order (apply all of them):**

```
Layer 1 — Transport:     HTTPS only. Redirect HTTP → HTTPS (301).
                         HSTS header: Strict-Transport-Security: max-age=31536000; includeSubDomains

Layer 2 — CORS:          Explicit allowlist of trusted origins.
                         NEVER: Access-Control-Allow-Origin: * with credentials: true
                         Preflight (OPTIONS) requests checked before complex requests.

Layer 3 — Authentication: JWT in Authorization header, or OAuth2 access token.
                         Stateless — no sessions. Token validated on every request.

Layer 4 — Authorization: After auth, check that user X is allowed to touch resource Y.
                         BOLA check: does this order/account/record belong to this user?

Layer 5 — Input validation: @Valid at controller layer, not just service layer.
                            Validate every field. Reject unknown fields.

Layer 6 — Mass assignment prevention: Never copy request body to entity directly.
                                      Use explicit DTOs with only allowed fields.

Layer 7 — Rate limiting:  Enforce per-client request limits. Prevent brute force + DoS.

Layer 8 — Security headers: X-Content-Type-Options, X-Frame-Options, Referrer-Policy.
```

**Mass assignment — the must-memorise gotcha:**

```java
// DANGEROUS — never do this
BeanUtils.copyProperties(request, userEntity);
// If request contains { "name": "Alice", "role": "ADMIN", "balance": 999999 }
// all those fields get copied onto the entity

// SAFE — explicit field mapping only
User user = new User();
user.setName(request.getName());         // only fields you intend to set
user.setEmail(request.getEmail());
user.setRole(Role.USER);                 // always set server-side, never from request
```

**BOLA (Broken Object Level Authorization) check — required on every resource access:**

```
GET /api/orders/{orderId}

1. Authenticate: extract userId from JWT
2. Fetch order from database by orderId
3. CHECK: order.customerId == authenticated userId?
   → No match: return 404 (not 403 — 403 confirms the resource exists,
                              enabling resource enumeration)
   → Match: return order data
```

**OWASP API Security Top 10 (2023) — know the names and one-line definitions:**

```
1. BOLA / IDOR         — Accessing another user's data by changing an ID in the URL
2. Broken Auth         — Weak tokens, no login rate limit, JWT without expiry
3. Broken Prop Auth    — Returning/accepting fields user shouldn't see or set
4. Unrestricted Consumption — No rate limiting, no pagination limits → DoS
5. Broken Function Auth — Regular users calling admin endpoints
6. Business Flow Abuse — Bypassing checkout steps, abusing discount codes
7. SSRF               — Server fetches attacker-controlled internal URLs
8. Security Misconfiguration — CORS *, verbose errors, default credentials
9. Improper Inventory — Undocumented deprecated API versions still live
10. Unsafe API Consumption — Blindly trusting third-party API responses
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check: BOLA
**"What is BOLA and how do you prevent it?"**

**One-line answer:** BOLA (Broken Object Level Authorization) is when an authenticated user accesses another user's resource by changing an ID in the URL — prevented by checking resource ownership on every request.

**Full answer to give in an interview:**

> "BOLA, also called IDOR — Insecure Direct Object Reference — is the number-one item on the OWASP API Security Top 10 because it's incredibly common and easy to miss. The scenario: user A is logged in and calls `GET /api/orders/12345`. The server authenticates them — JWT is valid — but then just fetches order 12345 from the database without checking whether it belongs to user A. User A simply increments the ID to 12346 and now sees user B's order. The fix is straightforward but must be applied consistently: after authenticating the user, always verify the resource belongs to them before returning it. In Spring Security, you inject `@AuthenticationPrincipal UserDetails currentUser` into the controller, fetch the order, then check `order.getCustomerId().equals(currentUser.getId())`. If the check fails, return 404 — not 403. Returning 403 Forbidden tells the attacker 'this resource exists but you can't see it,' which enables enumeration. Returning 404 gives nothing away."

> *Mention the 404 vs 403 distinction — interviewers love it.*

**Gotcha follow-up they'll ask:** *"Can't you just use UUIDs instead of sequential IDs to prevent BOLA?"*

> "UUIDs make BOLA harder by eliminating predictable enumeration — you can't just increment an integer. But they don't fix the underlying problem. If the attacker obtains a valid UUID (via a log leak, another API response, a shared link), they can still use it to access the resource. UUIDs are defence-in-depth, not a substitute for authorization checks. You need both: non-guessable IDs and explicit ownership verification."

---

##### Q2 — Tradeoff: CORS configuration
**"When would you use `Access-Control-Allow-Origin: *` and when is it dangerous?"**

**One-line answer:** Wildcard `*` is safe for fully public, unauthenticated APIs, but becomes a critical vulnerability the moment you also send `Access-Control-Allow-Credentials: true`.

**Full answer to give in an interview:**

> "CORS is the browser enforcing the same-origin policy on behalf of your users. When a JavaScript app on `evil.com` tries to call `api.bank.com`, the browser blocks it unless `api.bank.com` explicitly opts in via CORS headers. `Access-Control-Allow-Origin: *` means 'any website can call this API' — which is fine for genuinely public, read-only, unauthenticated data like a public weather API or open government dataset. The danger is combining `*` with `Access-Control-Allow-Credentials: true`. These two together mean: any website can make credentialed requests — requests that carry your users' cookies or auth tokens — to your API. The browser actually refuses this combination and throws an error, but developers sometimes try to work around it. In practice, for any API that involves authentication, I always use an explicit allowlist of trusted origins — `https://app.example.com`, `https://admin.example.com` — and never use `*` with credentials. The allowlist is checked server-side; if the request origin isn't in the list, the CORS headers simply aren't returned."

> *The fact that browsers reject the `* + credentials` combination is a common follow-up — know it.*

---

##### Q3 — Design Scenario: Preventing mass assignment
**"What is mass assignment and how do you prevent it in a Spring Boot API?"**

**One-line answer:** Mass assignment is when client-supplied fields are blindly copied onto a domain object, letting attackers set privileged fields like `role` or `isAdmin` — prevented with explicit DTOs and manual field mapping.

**Full answer to give in an interview:**

> "Mass assignment happens when you take the raw request body and copy it directly onto your domain entity — often using a utility like `BeanUtils.copyProperties()` or Jackson's `objectMapper.updateValue()`. The problem is the request body is attacker-controlled. If your `User` entity has a `role` field, the attacker just adds `'role': 'ADMIN'` to the JSON payload, and now they've promoted themselves. The fix has two parts. First, use separate request DTOs — a `CreateUserRequest` record that only contains the fields the user is allowed to supply: name, email, password. No `role`, no `balance`, no `isAdmin`. Second, do explicit field mapping in the controller or service: `user.setName(request.name()); user.setRole(Role.USER);` — the role is always set server-side. This also has the benefit of decoupling your API contract from your database schema, so internal refactoring doesn't accidentally expose new fields. Never pass a request object directly to a repository, and never annotate an `@Entity` class as a `@RequestBody`."

---

> **Common Mistake — Using `@Entity` as `@RequestBody`:** Annotating a JPA entity class directly as a Spring `@RequestBody` parameter exposes all database columns as settable fields, enables mass assignment for every field in the schema, and leaks your database structure in API docs. Always use a separate request DTO with only the fields you intend to accept.

---

**Quick Revision (one line):**
API security = HTTPS + HSTS, strict CORS allowlist (never `*` with credentials), `@Valid` input validation, explicit DTO mapping (no mass assignment), BOLA ownership check on every resource access (return 404 not 403 on failure), rate limiting, and knowing the OWASP API Top 10 by name.

---

## Topic 13: REST vs GraphQL vs gRPC

---

#### The Idea

Imagine you're at a restaurant. With REST, the menu is fixed: there's a "burger meal" that always comes with fries and a drink, whether you want them or not. If you want just the burger, you still get the full meal (over-fetching). If you want a burger and a side salad, that's a different menu item — a second trip to the waiter (under-fetching). REST is predictable and universally understood, but you get what the server decided to give you.

With GraphQL, the waiter brings you a blank order form. You write exactly what you want: "burger, no fries, extra pickles, and the salad from the other section." One trip, exactly what you asked for — no more, no less. This is powerful for complex data needs and multiple client types, but the kitchen (the server) has to be set up to handle arbitrary combinations of requests efficiently, or one badly written query can bring the whole restaurant to a standstill.

With gRPC, you're not in a restaurant at all — you're in a factory where two machines need to communicate at very high speed. There's no menu to read and no English to translate: the machines share a compiled blueprint (a `.proto` file) that both sides generate code from. Messages are packed in binary, not human-readable text, and the communication pipe is permanently open for streaming in both directions. This isn't for end users — it's for the internal plumbing of a system where performance and contract enforcement matter more than ease of use.

---

#### How It Works

**Side-by-side comparison across all key dimensions:**

| Dimension | REST | GraphQL | gRPC |
|---|---|---|---|
| Protocol | HTTP/1.1 or HTTP/2 | HTTP/1.1 or HTTP/2 (always POST) | HTTP/2 only |
| Payload format | JSON (usually) | JSON | Protocol Buffers (binary, ~10x smaller) |
| Schema | Optional (OpenAPI) | Required (SDL — Schema Definition Language) | Required (.proto file) |
| Fetching model | Multiple endpoints, fixed shape | Single endpoint, client defines shape | Generated typed client methods |
| Over-fetching | Common | Eliminated | N/A (typed fields only) |
| Under-fetching | Common (N+1 round trips) | Eliminated | N/A |
| Streaming | SSE or chunked transfer | Subscriptions over WebSocket | Native bidirectional streaming |
| Browser support | Full | Full | grpc-web only (requires proxy) |
| HTTP caching | Native (GET requests cache freely) | Difficult (everything is POST) | Not applicable |
| Type safety | Optional | Required (SDL enforced) | Strongly enforced (.proto compiled) |
| Code generation | Optional | Optional | Required (.proto → generated stubs) |
| Learning curve | Low | Medium | Medium–High |
| Best use case | Public APIs, CRUD, CDN-cached content | Complex data graphs, BFF layer, multiple client types | Internal microservices, high-performance, streaming |

**When to choose each:**

```
REST:
  - Public-facing API consumed by third parties
  - Simple CRUD operations
  - CDN caching is important
  - Team is unfamiliar with GraphQL/gRPC
  - Mobile clients on variable network conditions

GraphQL:
  - Complex, interconnected data (social graph, e-commerce catalog)
  - Multiple client types (mobile, web, TV) with very different data needs
  - Backend-for-Frontend (BFF) aggregation layer
  - Rapid product iteration — adding fields is non-breaking

gRPC:
  - Internal microservice-to-microservice communication
  - High throughput / low latency requirements
  - Bidirectional streaming (real-time updates, IoT telemetry, chat)
  - Strong contract enforcement between teams
  - Polyglot environments (Java service calling Go service)
```

**GraphQL's N+1 problem — the must-memorise gotcha:**

```
Query: { users { orders { total } } }

Naive implementation:
  SELECT * FROM users;          → returns 100 users
  SELECT * FROM orders WHERE userId = 1;   → 1 query
  SELECT * FROM orders WHERE userId = 2;   → 1 query
  ...
  SELECT * FROM orders WHERE userId = 100; → 1 query
  Total: 101 queries (1 + N)

DataLoader fix:
  Accumulate all userIds from the users result
  Fire ONE batch query: SELECT * FROM orders WHERE userId IN (1,2,...,100)
  Map results back to each user
  Total: 2 queries
```

**Protocol Buffers advantage over JSON:**

```
JSON (text):      {"id": 12345, "name": "Alice", "active": true}
                  → ~45 bytes, human-readable, parse overhead

Protobuf (binary): field 1 = 12345, field 2 = "Alice", field 3 = true
                  → ~15 bytes, not human-readable, faster parse
                  → schema enforced at compile time, type errors caught before runtime
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Tradeoff: Choosing between REST and GraphQL
**"You're building a new API for a product that has a mobile app, a web app, and a public developer API. Which do you choose: REST or GraphQL?"**

**One-line answer:** REST for the public developer API; GraphQL for the internal BFF layer serving mobile and web — each client gets exactly the data shape it needs.

**Full answer to give in an interview:**

> "I'd use a layered approach. For the public developer API, I'd use REST — it's universally understood, works naturally with HTTP caching for public endpoints, and is far easier for external developers to integrate with standard HTTP tooling. For the mobile app and web app, I'd add a GraphQL BFF — Backend for Frontend — layer that sits between the clients and the internal REST or gRPC services. The mobile app has different data needs than the web app: mobile wants minimal payloads to save bandwidth, web might want richer data with more joins. GraphQL lets each client query exactly what it needs without requiring the backend to maintain separate endpoints for each client's requirements. The GraphQL layer calls the internal REST or gRPC services, aggregates the results, and lets clients shape their own responses. This is exactly the pattern used by companies like Airbnb and Shopify — public REST API, internal GraphQL for their own frontends."

> *Mentioning BFF shows architectural maturity. Most candidates say "REST for simplicity" and stop there.*

**Gotcha follow-up they'll ask:** *"Doesn't GraphQL make caching impossible?"*

> "It makes HTTP caching harder because GraphQL uses POST for all queries, and POST responses are not cached by CDNs or browsers by default. But it's not impossible. Solutions: persisted queries (client sends a hash of the query instead of the full query body, server executes the stored query — then GET can be used and CDN caching applies), Apollo's response cache, or DataLoader-level caching. For truly cacheable public data, REST is genuinely simpler."

---

##### Q2 — Concept Check: When to use gRPC
**"Why would you use gRPC instead of REST for internal microservice communication?"**

**One-line answer:** gRPC gives you binary Protocol Buffer serialization (smaller, faster), strongly-typed contracts enforced at compile time, and native bidirectional streaming over HTTP/2 — all critical for high-throughput internal services.

**Full answer to give in an interview:**

> "For internal services communicating with each other thousands of times per second, the overhead of JSON parsing adds up. Protocol Buffers — gRPC's binary wire format — are roughly 3–10x smaller than equivalent JSON and parse significantly faster because the schema is compiled into the generated code rather than parsed at runtime. More importantly, gRPC enforces the contract at compile time. If Service A changes a field name in its `.proto` file, Service B's generated code won't compile until it's updated — you catch breaking changes before deployment, not in production at 3 AM. REST with JSON lets you rename fields silently and find out when clients start throwing null pointer exceptions. The third advantage is streaming: gRPC natively supports server streaming (one request, stream of responses), client streaming, and bidirectional streaming over a single persistent HTTP/2 connection — essential for real-time features like live order tracking, IoT sensor data, or event subscriptions. The tradeoff is browser support: gRPC requires HTTP/2 and binary framing that browsers don't natively support, so you can't call a gRPC service directly from JavaScript without grpc-web and a proxy. That's why gRPC is almost exclusively used for internal service-to-service communication."

---

##### Q3 — Design Scenario: GraphQL N+1
**"Your GraphQL API is slow when querying users and their orders. What's likely wrong and how do you fix it?"**

**One-line answer:** It's the N+1 problem — each user triggers a separate database query for their orders — fixed with DataLoader batching, which accumulates all IDs and fires one batch query.

**Full answer to give in an interview:**

> "The N+1 problem in GraphQL happens because each field resolver runs independently. When you query 100 users and each user has an `orders` field, the `orders` resolver fires once per user — that's 100 separate `SELECT * FROM orders WHERE userId = ?` queries on top of the initial user query. The fix is the DataLoader pattern, originally built by Facebook. DataLoader sits in front of your data source and batches requests within the same execution tick: instead of firing immediately, each resolver call schedules a load for a userId. At the end of the tick, DataLoader collects all scheduled userIds and fires a single `SELECT * FROM orders WHERE userId IN (1, 2, ..., 100)`. It then maps the results back to the correct user. In Spring for GraphQL, this is `@BatchMapping` — you annotate a method that receives a list of parent objects and returns a map of parent-to-children. One database round trip replaces 100."

> *The tick-based batching mechanism — 'accumulated within the same execution tick' — is what makes DataLoader elegant and is worth mentioning.*

---

> **Common Mistake — Using GraphQL for simple CRUD:** GraphQL adds real complexity: DataLoader setup to avoid N+1, query depth/complexity limits to prevent DoS attacks (a deeply nested query can fan out into thousands of database calls), schema stitching considerations, and harder caching. For a simple CRUD API with predictable data shapes, REST is faster to build, easier to cache, and easier for API consumers to understand. Choose GraphQL when you genuinely have multiple clients with different data needs.

---

**Quick Revision (one line):**
REST for public APIs and CDN-cacheable content; GraphQL for complex data graphs with multiple client types (use DataLoader to avoid N+1); gRPC for internal microservices where binary Protocol Buffers, compile-time contracts, and native streaming outweigh the lack of browser support.

---

## Topic 14: OpenAPI and Swagger

---

#### The Idea

Imagine you're building a bridge between two teams: one team builds the backend API, another team builds the mobile app that consumes it. Without a shared blueprint, the frontend team either waits for the backend to be done before they can start, or they guess at field names and get it wrong. OpenAPI is that shared blueprint — a machine-readable description of every endpoint, every request field, every possible response, written in YAML or JSON before a single line of implementation code is written.

The "Swagger" name causes confusion. Swagger 2.0 was the original specification. In 2016 it was donated to the Linux Foundation and renamed OpenAPI 3.0. Today, "Swagger" refers to the tooling suite — Swagger UI (interactive documentation), Swagger Editor (a browser-based spec editor) — while "OpenAPI" refers to the specification itself. They're from the same family; the name changed at version 3.

The real power of OpenAPI is what you can generate from a spec: interactive documentation that lets users try endpoints in the browser, client SDKs in a dozen languages (so Stripe can maintain Java, Python, TypeScript, and Go clients from one spec), server stubs that ensure your implementation matches the contract, and mock servers that let the frontend team develop against a fake backend before the real one exists. The spec becomes the source of truth for everyone.

---

#### How It Works

**OpenAPI 3.x document structure:**

```yaml
openapi: 3.1.0

info:           # Title, version, description, contact, license

servers:        # Base URLs for different environments
                # - https://api.example.com   (Production)
                # - https://staging-api.example.com  (Staging)

paths:          # All endpoints — the bulk of the spec
                # /orders:
                #   post:
                #     summary, operationId, requestBody, responses

components:     # Reusable building blocks
                # schemas: (request/response models)
                # responses: (reusable error responses)
                # parameters: (reusable query/path/header params)
                # securitySchemes: (JWT, API key, OAuth2)

security:       # Global security requirements (apply to all paths)

tags:           # Logical groupings (Orders, Users, Payments)
```

**Code-first vs Contract-first — the key tradeoff:**

```
Code-first:
  Write Java code → annotate with @Operation, @ApiResponse → generate spec
  Pro: Less upfront work; spec stays in sync automatically
  Con: API design is driven by implementation details
       (database column names leak in, awkward field naming, etc.)

Contract-first:
  Write OpenAPI spec → generate server stubs → implement the stubs
  Pro: API design is reviewed before writing code
       Frontend and backend can develop in parallel
       Client SDKs can be generated immediately
  Con: More upfront discipline required
       Requires a process to keep spec and implementation in sync
```

**The must-memorise gotcha — keeping spec and code in sync:**

```java
// Contract-first: implement the GENERATED interface
// OpenAPI Generator produces an OrderApi interface from order-api.yaml
// Your controller IMPLEMENTS that interface — the compiler enforces the contract

@RestController
public class OrderApiImpl implements OrderApi {
    // If the spec changes, the generated interface changes,
    // and THIS CLASS FAILS TO COMPILE until you update your implementation.
    // This is how contract-first catches drift between spec and code.

    @Override
    public ResponseEntity<OrderResponse> createOrder(CreateOrderRequest request) {
        return ResponseEntity.status(201).body(orderService.create(request));
    }
}

// Code-first: annotations on your controller generate the spec
@Operation(
    summary = "Create a new order",
    responses = {
        @ApiResponse(responseCode = "201", description = "Order created"),
        @ApiResponse(responseCode = "400", description = "Invalid request"),
        @ApiResponse(responseCode = "422", description = "Business rule violation")
    }
)
@PostMapping("/orders")
public ResponseEntity<OrderResponse> createOrder(@RequestBody @Valid CreateOrderRequest req) {
    // spec is generated from THIS annotation — not from a separate yaml file
}
```

**OpenAPI tooling ecosystem:**

```
Swagger UI        → Interactive HTML docs, try-it-in-browser
Redoc             → Beautiful read-only docs (better for external developers)
OpenAPI Generator → Generate client SDKs (Java, TypeScript, Python, Go, Ruby...)
                    and server stubs from a spec file
Prism             → Mock server: spin up a fake API from a spec in seconds
Spectral          → Linter: enforce naming conventions, require descriptions, etc.
Postman           → Import spec to generate a test collection automatically
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check: Swagger vs OpenAPI
**"What is the difference between Swagger and OpenAPI?"**

**One-line answer:** Swagger 2.0 was renamed OpenAPI 3.0 when donated to the Linux Foundation in 2016 — "OpenAPI" is now the specification, "Swagger" now refers to the tooling (Swagger UI, Swagger Editor).

**Full answer to give in an interview:**

> "This trips up a lot of people because the names are used interchangeably in job postings and tutorials. The history: SmartBear created the Swagger specification at version 2.0, then donated it to the Linux Foundation's OpenAPI Initiative, where it was rebranded OpenAPI Specification 3.0. The spec itself is now OpenAPI; version 2.0 is still called Swagger 2.0 for historical reasons. SmartBear retained the 'Swagger' brand for their tooling products: Swagger UI (the interactive documentation page you see at `/swagger-ui.html`), Swagger Editor (a browser-based YAML editor with live validation), and Swagger Hub (a cloud collaboration platform). So when someone says 'we use Swagger,' they usually mean they're using OpenAPI 3.x with SpringDoc's auto-generated spec and Swagger UI for documentation. If they literally mean Swagger 2.0, that's the older spec with slightly different syntax — notably, components were called `definitions`, and `requestBody` didn't exist yet."

---

##### Q2 — Tradeoff: Contract-first vs code-first
**"When would you choose contract-first API design over code-first?"**

**One-line answer:** Contract-first when multiple teams work in parallel, when client SDK generation is important, or when API design quality matters — the spec is reviewed and agreed before any code is written.

**Full answer to give in an interview:**

> "Code-first is pragmatic for small teams or internal APIs where speed of iteration matters more than API design formality — you write the code, annotate it, and a spec is generated automatically. It's the default in most Spring Boot tutorials. The problem is the spec reflects implementation decisions: field names match your Java class names, which may be database column names in disguise, response shapes include whatever the developer found convenient rather than what consumers need. Contract-first flips this. You design the API collaboratively — product, frontend, and backend together write or review the YAML spec. Only after the spec is signed off does implementation begin. This means the frontend team can use a mock server (Prism spins up a fake server from the spec in one command) and build the mobile app while the backend team implements against the same spec. The compiler enforces the contract: with OpenAPI Generator's contract-first mode, your Spring controller must implement the generated interface, so any drift between spec and code is a compile error, not a production incident."

**Gotcha follow-up they'll ask:** *"How do you prevent the OpenAPI spec from going stale after release?"*

> "Three techniques: (1) Contract-first with generated interfaces — the generated Java interface acts as a compile-time gate; if you add a field to the spec, the interface adds a parameter, and the code doesn't compile until you handle it. (2) Consumer-driven contract tests — using tools like Pact, consumers publish their expected request/response shape; the provider runs tests that verify it matches. (3) Integration tests that validate the running API against the spec — tools like Dredd or RestAssured can take the OpenAPI spec and run every documented example as a test."

---

##### Q3 — Design Scenario: Generating client SDKs
**"Stripe maintains client libraries in 8+ languages. How do they avoid maintaining 8 separate codebases by hand?"**

**One-line answer:** They maintain one OpenAPI spec and use OpenAPI Generator to auto-generate client SDKs for each language — all from a single source of truth.

**Full answer to give in an interview:**

> "Stripe publishes their OpenAPI spec on GitHub — `stripe/openapi` — and every client library (Java, Python, Ruby, TypeScript, Go, .NET, PHP, and more) is generated from it using OpenAPI Generator. The workflow: when Stripe adds a new API endpoint or field, they update the spec, run the generator for each target language, apply any manual customisations (retry logic, error handling, Stripe-specific conventions that the generator can't infer), and release a new version. The generated code handles all the HTTP boilerplate — constructing requests, parsing responses, mapping error codes to typed exceptions. The Stripe team only has to write the spec and the customisation layer once. This is the 'API-first' approach at scale: the spec is the product, the code is generated from it. In a typical enterprise context, even a simpler version of this — generating TypeScript client types for the frontend from the backend's OpenAPI spec — eliminates a whole class of frontend bugs where field names or types drift between backend and frontend."

---

> **Common Mistake — Stale documentation:** Generating an OpenAPI spec once at project start and never updating it is worse than having no spec — consumers build against the documented contract and discover the divergence in production. If you choose code-first, add a CI check that regenerates the spec on every build and fails if the committed spec doesn't match the generated one. If contract-first, enforce the generated interface in code.

---

**Quick Revision (one line):**
OpenAPI is the vendor-neutral spec (Swagger = the tooling, not the spec); contract-first design (spec before code) enables parallel frontend/backend development, auto-generated client SDKs, and mock servers; implement the generated interface for compile-time contract enforcement.

---

## Topic 15: API Gateway Patterns

---

#### The Idea

Imagine a large hospital. Instead of visitors wandering the corridors trying to find the right department, there's a reception desk at the entrance. The receptionist checks your identity (authentication), directs you to the right ward (routing), controls how many people can enter at once during a crisis (rate limiting), and logs every visit (observability). Critically, the receptionist doesn't perform surgery — they handle the logistics so the doctors (backend services) can focus on medicine. An API Gateway is that reception desk for a microservices architecture.

In a microservices system, without a gateway, every client — mobile app, web app, third-party partner — would need to know the network address of every individual service, handle authentication separately for each, and manage failures themselves. This is unmanageable when you have dozens or hundreds of services. The gateway is a single entry point that hides the internal topology entirely: from the outside it looks like one server; inside, it routes requests to whichever of your 200 microservices is responsible.

The most important anti-pattern to understand is the "fat gateway." If the gateway starts containing business logic — calculating discounts, orchestrating order flows, making domain decisions — it becomes the hardest component to change in your entire system, because every team's traffic flows through it. A good gateway is thin: authentication, routing, rate limiting, SSL termination, logging. Business logic belongs in the services it routes to.

---

#### How It Works

**Core gateway responsibilities (what belongs in the gateway):**

```
Routing            → Match path/host/method → forward to correct backend service
Authentication     → Validate JWT/API key before request reaches any service
                     Inject user identity into downstream request headers
Rate Limiting      → Enforce per-client, per-endpoint limits centrally
SSL Termination    → Handle TLS at the gateway; services communicate over plain HTTP internally
Load Balancing     → Distribute requests across service instances
Circuit Breaking   → Stop forwarding to failing services; return fallback immediately
Request Transform  → Rewrite paths, add/remove headers, inject correlation IDs
Protocol Translate → External REST → internal gRPC; WebSocket → HTTP
Observability      → Centralized logging, inject X-Correlation-Id for distributed tracing
Caching            → Cache responses at gateway layer (avoid for user-specific data)
```

**Key gateway patterns:**

```
1. Backend for Frontend (BFF):
   Each client type (mobile, web, TV) has its own gateway instance
   that aggregates and shapes data specifically for that client.
   Avoids "one-size-fits-all" API that serves no one well.
   Netflix uses per-device BFFs.

2. Request Fanout / Aggregation:
   One client request → gateway calls 3 backend services in parallel
   → combines results → one response to client.
   Useful for dashboard endpoints.
   (Alternative: dedicated orchestration service to avoid fat gateway)

3. Protocol Translation:
   External clients speak REST; internal services speak gRPC.
   Gateway translates between protocols.
   Clients don't need to know internal protocol choices.

4. API Gateway vs Service Mesh:
   Gateway = North-South traffic (external client → backend)
   Service Mesh (Istio, Linkerd) = East-West traffic (service → service)
   Use both: gateway for external entry, mesh for internal communication.
```

**The must-memorise gotcha — JWT auth at the gateway with downstream enrichment:**

```java
// Gateway JWT filter — authenticate once, enrich downstream headers
// so each microservice knows who the user is WITHOUT re-validating the token

String token = request.getHeader("Authorization").substring(7); // strip "Bearer "
Claims claims = jwtValidator.validate(token);  // validate signature + expiry

// Mutate the downstream request — services trust these headers (internal network only)
ServerHttpRequest enriched = request.mutate()
    .header("X-User-Id",   claims.getUserId())   // "user-123"
    .header("X-User-Role", claims.getRole())     // "ADMIN"
    .header("X-Correlation-Id", UUID.randomUUID().toString())  // for tracing
    .build();
// Forward enriched request to backend service
// Backend service reads X-User-Id from header — no JWT library needed in each service
```

**Circuit breaker fallback pattern:**

```
Normal:   Client → Gateway → Order Service → 200 OK
Failure:  Client → Gateway → Order Service [down] → circuit opens
Fallback: Client → Gateway → Fallback Controller → 503 Service Unavailable
                                                     Retry-After: 30
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check: Gateway vs service mesh
**"What is the difference between an API Gateway and a service mesh like Istio?"**

**One-line answer:** An API Gateway handles North-South traffic (external clients entering the system); a service mesh handles East-West traffic (internal service-to-service communication) — they solve different problems and are often used together.

**Full answer to give in an interview:**

> "The distinction is about traffic direction. An API Gateway sits at the perimeter of your system and handles 'North-South' traffic — requests coming in from outside, typically from browsers, mobile apps, or third-party API consumers. It handles authentication, rate limiting, SSL termination, and routing to the correct internal service. A service mesh like Istio or Linkerd handles 'East-West' traffic — the communication between services that are already inside your system. Service A calling Service B calling Service C. The mesh injects a sidecar proxy (Envoy, in Istio's case) into every service pod; these proxies intercept all inter-service traffic and give you mutual TLS between services, retry logic, circuit breaking, distributed tracing, and traffic splitting for canary deployments — all without touching application code. In a mature microservices architecture you use both: the API Gateway is the front door, the service mesh is the internal nervous system. They're complementary, not competing."

**Gotcha follow-up they'll ask:** *"Can't a service mesh replace the API Gateway entirely?"*

> "Technically a service mesh can handle ingress traffic with an ingress gateway component, but in practice the concerns are different enough that they're kept separate. API Gateways are optimized for external-facing concerns: OAuth2 flows, API key management, developer portal integration, per-consumer rate limiting, and request transformation for external contracts. Service meshes are optimized for internal reliability: mTLS, fine-grained traffic control, and observability between services. Consolidating both into one creates a component that's doing too many things — the fat gateway anti-pattern extended to the entire network layer."

---

##### Q2 — Design Scenario: BFF pattern
**"Your mobile app is slow because it makes 5 separate API calls to build the dashboard screen. How do you fix this with an API Gateway pattern?"**

**One-line answer:** Implement a Backend for Frontend (BFF) that fans out to the 5 services in parallel on the server side, returning a single aggregated response to the mobile app in one round trip.

**Full answer to give in an interview:**

> "The mobile app's problem is latency multiplication: 5 sequential round trips over a mobile network, each with 50–200ms latency, adds up to 500ms–1 second before the screen can render. Even in parallel, the mobile client is doing network orchestration that belongs on the server. The BFF pattern creates a purpose-built aggregation endpoint specifically for the mobile dashboard. The gateway — or a dedicated BFF service — receives one request from the mobile app, fans out to the 5 backend services concurrently using reactive async calls, and waits for all of them (with per-service timeouts). Services that are non-critical — like a notifications count — use `.onErrorReturn(0L)` to degrade gracefully rather than failing the entire dashboard. The mobile app makes one network request and gets back exactly the data shape it needs for that screen. A web app that needs a different data shape gets its own BFF endpoint with its own aggregation logic. This is the Netflix model: device-specific BFF layers that shape data for Roku, PlayStation, iPhone, and browser without each requiring different backend endpoints."

> *Mention graceful degradation — non-critical services failing shouldn't break the whole response. Interviewers love this detail.*

---

##### Q3 — Tradeoff: Fat gateway anti-pattern
**"What is the fat gateway anti-pattern and why is it dangerous?"**

**One-line answer:** A fat gateway contains business logic that belongs in services — making it a single point of coupling for every team, impossible to change without coordination across the entire organisation.

**Full answer to give in an interview:**

> "The gateway is the one component that every team's traffic flows through. If business logic lives there — discount calculations, order orchestration, data transformation specific to one product feature — then every change to that logic requires a gateway deployment. Gateway deployments are organisationally expensive: they affect every team, require extensive testing because a bug takes down all traffic, and create a deployment bottleneck. The gateway should be infrastructure, not application code. The test I apply is: if a new developer joins the payments team, should they ever need to understand or change gateway code? If the answer is yes, that logic is in the wrong place. Concretely: routing rules, authentication, rate limiting, SSL termination, and correlation ID injection belong in the gateway. Calculating whether a user qualifies for a discount, deciding which payment provider to use, or transforming a response to match a specific client's data model — those belong in a service. For aggregation that feels like it 'needs to be in the gateway,' create a dedicated BFF service that the gateway routes to, rather than putting the aggregation logic in the gateway itself."

---

> **Common Mistake — Single gateway as single point of failure:** Deploying the API Gateway as a single instance means one process handles all external traffic. Any crash, memory leak, or slow deployment takes down the entire system. API Gateways must be deployed in high-availability configuration — multiple instances behind a load balancer, stateless so any instance handles any request, with health checks and auto-restart. Spring Cloud Gateway uses reactive (non-blocking) I/O precisely because blocking on thousands of concurrent connections would require thousands of threads.

---

**Quick Revision (one line):**
An API Gateway is the single entry point handling routing, authentication, rate limiting, SSL termination, and observability; use BFF to aggregate multiple service calls into one client response; keep the gateway thin (no business logic); deploy in HA; API Gateway handles North-South traffic while a service mesh (Istio) handles East-West.

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
