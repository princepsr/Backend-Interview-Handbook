# Volume 2: Spring — Company Guide

## Which Companies Go Deep on Spring

| Company | Spring Depth (1-5) | Focus Area | Key Chapters |
|---|---|---|---|
| Atlassian | 5 | Custom auto-config, Security, multi-tenant | Ch7 |
| Salesforce | 5 | Spring Data, AOP, DI at scale | Ch7, Ch8 |
| Thoughtworks | 4 | Clean architecture, DDD with Spring Data | Ch7, Ch8 |
| Amazon | 3 | Spring Boot config, `@Transactional` in distributed | Ch7, Ch8 |
| Stripe | 4 | Production patterns, observability, error handling | Ch7 |
| Flipkart | 4 | REST + JPA + cache integration, pitfalls | Ch7, Ch8 |
| Swiggy / CRED | 3 | Practical Spring Boot, JPA performance | Ch8 |
| Goldman Sachs | 3 | Transaction management, thread safety in Spring beans | Ch7, Ch8 |

---

## Company-Specific Tips

### Atlassian / Salesforce
- Both run large platform products where Spring is customized extensively — expect questions on writing custom `BeanPostProcessor`, `BeanFactoryPostProcessor`, or `ApplicationContextInitializer`
- Multi-tenant patterns come up: tenant-aware `DataSource` routing (`AbstractRoutingDataSource`), request-scoped tenant context, and how Spring Security's `SecurityContextHolder` interacts with it
- Spring Security depth matters here: OAuth2 resource server configuration, method-level security (`@PreAuthorize`), and how to test secured endpoints with `@WithMockUser`

### Amazon
- Amazon uses Spring Boot extensively but interviews focus on distributed system concerns — how `@Transactional` behaves when the underlying call is to an external service (it does not help; you need saga/outbox)
- Expect DI pattern questions in the context of testability — constructor injection vs field injection, and why field injection makes unit testing harder
- Spring Boot configuration management: `@ConfigurationProperties`, profiles, externalized config via environment variables — know how 12-factor app principles map to Spring Boot

### Stripe
- Stripe values production-ready Spring Boot — expect questions on Actuator endpoints (`/health`, `/metrics`, `/info`), custom health indicators, and Micrometer metrics
- Error handling patterns matter: `@ControllerAdvice`, `@ExceptionHandler`, `ProblemDetail` (RFC 7807), and returning consistent error responses
- Observability: structured logging with MDC (correlation IDs), distributed tracing with Spring Cloud Sleuth or Micrometer Tracing, and how to propagate trace context across async boundaries

### Thoughtworks
- Thoughtworks emphasizes clean architecture — they will ask how you structure a Spring Boot application to separate domain logic from infrastructure (Spring Data repositories, REST controllers)
- DDD with Spring Data: aggregate roots, repository-per-aggregate, domain events published via `ApplicationEventPublisher`
- Testability is a first-class concern: they want to see proper integration tests with `@SpringBootTest`, slice tests with `@DataJpaTest`, and mocked dependencies with `@MockBean`

### Flipkart / Indian Product (Swiggy, CRED, Zepto)
- Practical Spring Boot with Redis integration: `@Cacheable`, `@CacheEvict`, cache key strategy, and TTL configuration
- JPA performance issues in high-traffic scenarios: N+1 in list APIs, missing indexes found via slow query log, `@QueryHints` for read-only queries
- Common REST API pitfalls they test: pagination with `Pageable`, DTO projection vs entity exposure, and `@JsonIgnore` vs Jackson `@JsonView` for selective serialization

---

## The 5 Spring Questions That Always Come Up

1. **"Explain `@Transactional` — what are the most common ways it silently does nothing?"**
   Strong answer: self-invocation bypasses proxy; `private` method annotation is ignored; checked exceptions do not roll back by default; calling from a non-Spring-managed class skips the proxy entirely.

2. **"How does Spring Boot auto-configuration work?"**
   Strong answer: `@EnableAutoConfiguration` triggers `AutoConfigurationImportSelector`, which reads `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`; each auto-config class uses `@Conditional` variants to decide whether to apply; user-defined beans take precedence via `@ConditionalOnMissingBean`.

3. **"What is the N+1 problem and how do you fix it in a real Spring Data JPA repository?"**
   Strong answer: name the cause (separate SELECT per association), show detection via Hibernate statistics or slow log, give three fixes: `@Query` with `JOIN FETCH`, `@EntityGraph` on the repository method, or `@BatchSize` on the association — and note that `JOIN FETCH` with pagination requires a count query and `HHH90003004` warning.

4. **"How do you make a Spring Boot service observable in production?"**
   Strong answer: Actuator for health and metrics; Micrometer for custom metrics (counters, timers, gauges); MDC for correlation IDs in logs; distributed tracing via Micrometer Tracing with a Zipkin/Jaeger exporter; structured JSON logging for log aggregation.

5. **"You have a singleton Spring bean with a stateful field — what can go wrong and how do you fix it?"**
   Strong answer: singleton beans are shared across all threads; a mutable instance field is a race condition; fix with `ThreadLocal`, redesign to stateless, or change scope to `request`/`prototype` — and explain the cost of each approach.
