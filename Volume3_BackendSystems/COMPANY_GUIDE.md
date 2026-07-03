# Volume 3: Backend Systems — Company Guide

## Which Companies Go Deep on Backend Systems

| Company | Kafka (1-5) | Redis (1-5) | Microservices (1-5) | Security (1-5) |
|---|---|---|---|---|
| Uber / Lyft | 5 | 5 | 5 | 3 |
| Netflix | 5 | 4 | 5 | 3 |
| Stripe | 4 | 3 | 4 | 5 |
| Amazon / AWS | 4 | 3 | 5 | 4 |
| Google | 3 | 3 | 4 | 4 |
| Flipkart / Swiggy / Zepto | 4 | 4 | 4 | 2 |
| Atlassian | 3 | 3 | 3 | 5 |
| Goldman Sachs / FinTech | 2 | 3 | 3 | 4 |

---

## Company-Specific Tips

### Uber / Lyft
Kafka is core infrastructure — expect questions on real-time location event streams, partition assignment for driver IDs, and what happens when a consumer group falls behind. Redis is used for driver-matching geospatial lookups (`GEORADIUS`), surge pricing state, and rate limiting. Microservices questions emphasize decomposition by domain (dispatch, pricing, matching) and service-to-service failure modes. Know the Outbox pattern cold — they care about dual-write problems in event-sourced architectures.

### Netflix
Kafka backs the entire event-streaming pipeline; expect questions on fan-out (one topic, many consumer groups), replay for A/B test analysis, and schema evolution with Avro. Redis is used for session storage and request caching at the edge. Circuit breakers originated here (Hystrix) — understand all three states and how half-open prevents thundering herd. Chaos engineering context helps: they assume services fail and ask how your design survives it.

### Stripe
Idempotency is the central interview theme — how do you design a payment API that handles duplicate requests from retrying clients without double-charging? Outbox pattern for exactly-once event publishing alongside payment records. Kafka consumers must be idempotent themselves (same event processed twice = same outcome). JWT and OAuth2 are tested deeply: token validation, short-lived access tokens, refresh token rotation, and scopes. CORS and CSRF matter because Stripe's APIs are called from browsers.

### Amazon / AWS
Microservices at scale is their domain — service discovery, load balancing, health checks, and graceful degradation. Expect Kafka vs SQS comparison: when does managed simplicity (SQS) beat Kafka's replay and consumer group model? Security layer: IAM roles for service-to-service auth, API Gateway JWT validation, CORS configuration at the gateway level. Know when REST over HTTP/2 beats gRPC in their ecosystem.

### Flipkart / Indian Product (Swiggy, Zepto)
Kafka for order lifecycle events (placed → confirmed → dispatched → delivered) — expect questions on handling duplicate order events and out-of-order delivery. Redis is heavily used for cart storage, session management, and rate limiting flash sales. Microservices questions are practical: how do you prevent cascading failures during a sale spike? Know Redis Sorted Sets for leaderboard/ranking use cases — common in these domains.

### Atlassian
Event-driven architecture for Jira/Confluence workflows — expect REST API design depth: versioning strategy, backward compatibility, HATEOAS for navigability. OAuth2 and SAML for enterprise SSO are first-class topics; know the difference between OAuth2 scopes and SAML assertions. Multi-tenant concerns: how do you isolate event streams per tenant in Kafka? Know token introspection and short-lived JWT strategies for enterprise security requirements.

---

## The 5 Backend Systems Questions That Always Come Up

1. **"Design a notification system for 10M users."**
   Strong answer requires: Kafka for fan-out, consumer groups per channel (email/push/SMS), dead-letter queue for retries, Redis for dedup within a time window, idempotent consumers, and a status API backed by a DB.

2. **"How do you ensure a Kafka consumer processes each message exactly once?"**
   Strong answer: producer idempotence + transactions, consumer idempotent logic, commit offset only after successful processing — and acknowledge that true EOS requires all three layers.

3. **"Your Redis cache is under memory pressure. Walk me through your eviction strategy."**
   Strong answer: distinguish volatile-lru vs allkeys-lru, explain what data you can afford to evict vs what requires TTL-only eviction, mention monitoring hit/miss ratio.

4. **"A microservice call fails 30% of the time under load. How do you handle this?"**
   Strong answer: Circuit Breaker (don't keep hammering), bulkhead isolation, timeout + retry with exponential backoff, fallback response — and know that retrying without backoff makes it worse.

5. **"How does OAuth2 authorization code flow work, and why is the code exchanged server-side?"**
   Strong answer: client gets code in redirect, server exchanges code + secret for token — access token never touches browser URL bar; explain PKCE for public clients.
